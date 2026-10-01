`timescale 1ns / 1ps

// Testbench para rx_interface.v. Lo prueba junto a un uart_rx.v real (ya
// validado en su propio testbench): el testbench maneja la linea serie
// `rx` como en uart_rx_tb.v, y ademas hace de "ALU" leyendo con rd/r_data
// y mirando rx_empty.
//   iverilog -o sim.out ../rtl/rx_interface.v ../rtl/uart_rx.v rx_interface_tb.v && vvp sim.out

module rx_interface_tb;

    localparam integer DBIT       = 8;
    localparam integer SB_TICK    = 16;
    localparam integer CLK_PERIOD = 10;
    localparam integer TICK_DIV   = 4;

    reg clk, reset;
    reg rx;
    wire rx_done;
    wire [DBIT-1:0] d_out;
    wire [DBIT-1:0] r_data;
    reg rd;
    wire rx_empty;

    integer errors = 0;
    integer checks = 0;

    reg [$clog2(TICK_DIV)-1:0] tick_cnt = 0;
    reg s_tick_r = 1'b0;

    uart_rx #(
        .DBIT    (DBIT),
        .SB_TICK (SB_TICK)
    ) dut_rx (
        .clk     (clk),
        .reset   (reset),
        .rx      (rx),
        .s_tick  (s_tick_r),
        .rx_done (rx_done),
        .d_out   (d_out)
    );

    rx_interface dut_if (
        .clk      (clk),
        .reset    (reset),
        .rx_done  (rx_done),
        .d_out    (d_out),
        .r_data   (r_data),
        .rd       (rd),
        .rx_empty (rx_empty)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    always @(posedge clk) begin
        if (tick_cnt == TICK_DIV-1) begin
            tick_cnt <= 0;
            s_tick_r <= 1'b1;
        end else begin
            tick_cnt <= tick_cnt + 1'b1;
            s_tick_r <= 1'b0;
        end
    end

    task automatic wait_ticks(input integer n);
        integer j;
        begin
            for (j = 0; j < n; j = j + 1)
                @(posedge s_tick_r);
        end
    endtask

    task automatic send_byte(input [DBIT-1:0] data);
        integer i;
        begin
            rx = 1'b0;
            wait_ticks(16);
            for (i = 0; i < DBIT; i = i + 1) begin
                rx = data[i];
                wait_ticks(16);
            end
            rx = 1'b1;
            wait_ticks(SB_TICK);
        end
    endtask

    // Espera a que rx_empty baje (dato disponible), con timeout generoso.
    task automatic wait_for_data(output reg got);
        integer w;
        begin
            w = 0;
            while (rx_empty && w < 800) begin
                @(posedge clk);
                w = w + 1;
            end
            got = !rx_empty;
        end
    endtask

    task automatic check_byte(input [DBIT-1:0] data);
        reg got;
        integer local_errors;
        begin
            local_errors = 0;

            checks = checks + 1;
            if (!rx_empty) begin
                local_errors = local_errors + 1;
                $display("FAIL data=%h: rx_empty ya estaba en 0 antes de mandar el byte", data);
            end

            send_byte(data);

            wait_for_data(got);
            checks = checks + 1;
            if (!got) begin
                local_errors = local_errors + 1;
                $display("FAIL data=%h: rx_empty nunca bajo (no llego el dato)", data);
            end else if (r_data !== data) begin
                local_errors = local_errors + 1;
                $display("FAIL data=%h: r_data=%h", data, r_data);
            end

            // La ALU lee el dato
            rd = 1'b1;
            @(posedge clk);
            rd = 1'b0;
            @(posedge clk);

            checks = checks + 1;
            if (!rx_empty) begin
                local_errors = local_errors + 1;
                $display("FAIL data=%h: rx_empty no volvio a 1 despues de rd", data);
            end

            if (local_errors == 0)
                $display("OK   data=%h recibido, leido con rd y rx_empty liberado correctamente", data);
            else
                errors = errors + 1;

            rx = 1'b1;
            wait_ticks(8);
        end
    endtask

    initial begin
        clk   = 1'b0;
        reset = 1'b1;
        rx    = 1'b1;
        rd    = 1'b0;
        repeat (4) @(negedge clk);
        reset = 1'b0;
        wait_ticks(4);

        checks = checks + 1;
        if (!rx_empty) begin
            errors = errors + 1;
            $display("FAIL: rx_empty deberia estar en 1 tras el reset");
        end else begin
            $display("OK   rx_empty en 1 tras el reset");
        end

        check_byte(8'h00);
        check_byte(8'hFF);
        check_byte(8'hA5);
        check_byte(8'h55);
        check_byte(8'h01);
        check_byte(8'h80);

        // Prueba de overrun: dos bytes seguidos sin leer el primero. El
        // segundo (0x22) debe pisar al primero (0x11), que se pierde.
        begin : overrun_test
            reg got;

            checks = checks + 1;
            send_byte(8'h11);
            wait_for_data(got);
            if (!got || r_data !== 8'h11) begin
                errors = errors + 1;
                $display("FAIL overrun: no llego bien el primer byte (0x11), r_data=%h", r_data);
            end

            // manda el segundo SIN leer el primero (rx_empty ya esta en 0,
            // asi que no sirve esperar con wait_for_data; alcanza con dejar
            // pasar un par de ticks despues de que send_byte termine)
            send_byte(8'h22);
            wait_ticks(2);

            checks = checks + 1;
            if (rx_empty) begin
                errors = errors + 1;
                $display("FAIL overrun: rx_empty quedo en 1 en vez de reflejar el dato pisado");
            end else if (r_data !== 8'h22) begin
                errors = errors + 1;
                $display("FAIL overrun: r_data=%h, se esperaba que el byte nuevo (0x22) pisara al viejo", r_data);
            end else begin
                $display("OK   overrun: el byte nuevo (0x22) piso al no leido (0x11) como se diseno");
            end

            rd = 1'b1;
            @(posedge clk);
            rd = 1'b0;
            rx = 1'b1;
            wait_ticks(8);
        end

        check_byte(8'h3C);

        if (errors == 0)
            $display("TEST PASSED: %0d checks, 0 errors", checks);
        else
            $display("TEST FAILED: %0d checks, %0d errors", checks, errors);

        $finish;
    end

endmodule
