`timescale 1ns / 1ps

// Testbench autocontenido para uart_tx.v (sin includes ni tasks
// compartidas). Igual que en uart_rx_tb.v, genera su propio s_tick con un
// divisor chico para simular rapido; no usa baud_rate_gen.
//
// A diferencia del Rx (donde el testbench maneja la linea serie y el DUT
// arma un byte en paralelo), aca el testbench le da un byte en paralelo al
// DUT y verifica la linea serie `tx` directamente contra el tiempo real:
// mide el flanco de bajada del bit de Start con @(negedge tx) y a partir
// de ahi va muestreando cada bit al medio de su periodo (BIT_NS), sin
// asumir nada sobre la cuenta interna de ciclos del DUT.
//   iverilog -o sim.out ../rtl/uart_tx.v uart_tx_tb.v && vvp sim.out

module uart_tx_tb;

    localparam integer DBIT       = 8;
    localparam integer SB_TICK    = 16;
    localparam integer CLK_PERIOD = 10;  // ns
    localparam integer TICK_DIV   = 4;   // s_tick cada TICK_DIV ciclos de clk
    localparam integer BIT_NS     = 16 * TICK_DIV * CLK_PERIOD; // duracion real de 1 bit

    reg clk, reset;
    reg tx_start;
    reg [DBIT-1:0] d_in;
    wire tx_done;
    wire tx;

    integer errors = 0;
    integer checks = 0;

    // Generador de s_tick local al testbench (ver nota en uart_rx_tb.v).
    reg [$clog2(TICK_DIV)-1:0] tick_cnt = 0;
    reg s_tick_r = 1'b0;

    uart_tx #(
        .DBIT    (DBIT),
        .SB_TICK (SB_TICK)
    ) dut (
        .clk      (clk),
        .reset    (reset),
        .tx_start (tx_start),
        .s_tick   (s_tick_r),
        .d_in     (d_in),
        .tx_done  (tx_done),
        .tx       (tx)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    always @(posedge clk) begin
        if (tick_cnt == TICK_DIV-1) begin
            tick_cnt  <= 0;
            s_tick_r  <= 1'b1;
        end else begin
            tick_cnt  <= tick_cnt + 1'b1;
            s_tick_r  <= 1'b0;
        end
    end

    // Marca si tx_done pulso durante el frame que se esta verificando.
    reg tx_done_seen = 1'b0;
    always @(posedge tx_done) tx_done_seen = 1'b1;

    task automatic check_byte(input [DBIT-1:0] data);
        integer i;
        integer local_errors;
        begin
            tx_done_seen = 1'b0;
            local_errors = 0;

            // Pulso de 1 ciclo para arrancar la transmision
            tx_start = 1'b1;
            d_in     = data;
            @(posedge clk);
            tx_start = 1'b0;

            // Encuentra el flanco de bajada real del bit de Start (sin
            // asumir cuantos ciclos de clk tarda el DUT en reaccionar)
            @(negedge tx);

            // Centro del bit de Start
            #(BIT_NS/2);
            if (tx !== 1'b0) begin
                local_errors = local_errors + 1;
                $display("FAIL data=%h: bit de Start no esta en 0 (tx=%b)", data, tx);
            end

            // Centro de cada bit de datos, LSB primero
            for (i = 0; i < DBIT; i = i + 1) begin
                #(BIT_NS);
                if (tx !== data[i]) begin
                    local_errors = local_errors + 1;
                    $display("FAIL data=%h: bit %0d esperado=%b leido=%b", data, i, data[i], tx);
                end
            end

            // Centro del bit de Stop
            #(BIT_NS);
            if (tx !== 1'b1) begin
                local_errors = local_errors + 1;
                $display("FAIL data=%h: bit de Stop no esta en 1 (tx=%b)", data, tx);
            end

            // Margen para que tx_done, si va a pulsar, ya lo haya hecho
            #(BIT_NS/2);

            checks = checks + 1;
            if (!tx_done_seen) begin
                local_errors = local_errors + 1;
                $display("FAIL data=%h: tx_done nunca se activo", data);
            end

            if (local_errors == 0)
                $display("OK   data=%h transmitido correctamente", data);
            else
                errors = errors + 1;

            // Hueco en idle antes del siguiente frame
            #(BIT_NS/2);
        end
    endtask

    initial begin
        clk      = 1'b0;
        reset    = 1'b1;
        tx_start = 1'b0;
        d_in     = {DBIT{1'b0}};
        repeat (4) @(negedge clk);
        reset = 1'b0;
        #(BIT_NS);

        checks = checks + 1;
        if (tx !== 1'b1) begin
            errors = errors + 1;
            $display("FAIL: tx deberia estar en reposo (1) tras el reset, esta en %b", tx);
        end else begin
            $display("OK   tx en reposo (1) tras el reset");
        end

        check_byte(8'h00);
        check_byte(8'hFF);
        check_byte(8'hA5);
        check_byte(8'h55);
        check_byte(8'h01);
        check_byte(8'h80);
        check_byte(8'h3C);

        if (errors == 0)
            $display("TEST PASSED: %0d checks, 0 errors", checks);
        else
            $display("TEST FAILED: %0d checks, %0d errors", checks, errors);

        $finish;
    end

endmodule
