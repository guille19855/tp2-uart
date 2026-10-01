`timescale 1ns / 1ps

// Testbench para tx_interface.v. Lo prueba junto a un uart_tx.v real (ya
// validado en su propio testbench), asi se verifica la interfaz tal como
// la va a usar la ALU: escribe con w_data/wr y controla tx_full, mientras
// el testbench mide la linea serie `tx` igual que en uart_tx_tb.v.
//   iverilog -o sim.out ../rtl/tx_interface.v ../rtl/uart_tx.v tx_interface_tb.v && vvp sim.out

module tx_interface_tb;

    localparam integer DBIT       = 8;
    localparam integer SB_TICK    = 16;
    localparam integer CLK_PERIOD = 10;
    localparam integer TICK_DIV   = 4;
    localparam integer BIT_NS     = 16 * TICK_DIV * CLK_PERIOD;

    reg clk, reset;
    reg [DBIT-1:0] w_data;
    reg wr;
    wire tx_full;
    wire [DBIT-1:0] d_in;
    wire tx_start;
    wire tx_done;
    wire tx;

    integer errors = 0;
    integer checks = 0;

    reg [$clog2(TICK_DIV)-1:0] tick_cnt = 0;
    reg s_tick_r = 1'b0;

    tx_interface dut_if (
        .clk     (clk),
        .reset   (reset),
        .w_data  (w_data),
        .wr      (wr),
        .tx_full (tx_full),
        .d_in    (d_in),
        .tx_start(tx_start),
        .tx_done (tx_done)
    );

    uart_tx #(
        .DBIT    (DBIT),
        .SB_TICK (SB_TICK)
    ) dut_tx (
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
            tick_cnt <= 0;
            s_tick_r <= 1'b1;
        end else begin
            tick_cnt <= tick_cnt + 1'b1;
            s_tick_r <= 1'b0;
        end
    end

    task automatic check_byte(input [DBIT-1:0] data);
        integer i;
        integer local_errors;
        begin
            local_errors = 0;

            checks = checks + 1;
            if (tx_full) begin
                local_errors = local_errors + 1;
                $display("FAIL data=%h: tx_full ya estaba en 1 antes de escribir", data);
            end

            // Escritura de 1 ciclo, como la haria la ALU
            w_data = data;
            wr     = 1'b1;
            @(posedge clk);
            wr = 1'b0;

            @(posedge clk);
            checks = checks + 1;
            if (!tx_full) begin
                local_errors = local_errors + 1;
                $display("FAIL data=%h: tx_full no subio despues de escribir", data);
            end

            // Verifica la linea serie igual que en uart_tx_tb.v
            @(negedge tx);
            #(BIT_NS/2);
            if (tx !== 1'b0) begin
                local_errors = local_errors + 1;
                $display("FAIL data=%h: bit de Start no esta en 0", data);
            end
            for (i = 0; i < DBIT; i = i + 1) begin
                #(BIT_NS);
                if (tx !== data[i]) begin
                    local_errors = local_errors + 1;
                    $display("FAIL data=%h: bit %0d esperado=%b leido=%b", data, i, data[i], tx);
                end
            end
            #(BIT_NS);
            if (tx !== 1'b1) begin
                local_errors = local_errors + 1;
                $display("FAIL data=%h: bit de Stop no esta en 1", data);
            end

            // Margen para que tx_done libere tx_full
            #(BIT_NS);
            checks = checks + 1;
            if (tx_full) begin
                local_errors = local_errors + 1;
                $display("FAIL data=%h: tx_full sigue en 1 despues de terminar", data);
            end

            if (local_errors == 0)
                $display("OK   data=%h escrito, transmitido y tx_full liberado correctamente", data);
            else
                errors = errors + 1;

            #(BIT_NS/2);
        end
    endtask

    initial begin
        clk    = 1'b0;
        reset  = 1'b1;
        wr     = 1'b0;
        w_data = {DBIT{1'b0}};
        repeat (4) @(negedge clk);
        reset = 1'b0;
        #(BIT_NS);

        checks = checks + 1;
        if (tx_full) begin
            errors = errors + 1;
            $display("FAIL: tx_full deberia estar en 0 tras el reset");
        end else begin
            $display("OK   tx_full en 0 tras el reset");
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
