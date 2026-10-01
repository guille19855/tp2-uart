`timescale 1ns / 1ps

// Testbench minimo y autocontenido para baud_rate_gen.v (sin includes ni
// tasks compartidas, mismo estilo que tb/alu_tb_simple.v). Usa un DVSR
// chico para que la simulacion sea rapida:
//   iverilog -o sim.out ../rtl/baud_rate_gen.v baud_rate_gen_tb.v && vvp sim.out

module baud_rate_gen_tb;

    localparam integer DVSR = 5;   // periodo esperado: DVSR ciclos de clk
    localparam integer CLK_PERIOD = 10; // ns

    reg clk;
    reg reset;
    wire tick;

    integer errors = 0;
    integer checks = 0;
    integer tick_num = 0;
    time    last_tick_time = 0;

    baud_rate_gen #(
        .DVSR(DVSR)
    ) dut (
        .clk   (clk),
        .reset (reset),
        .tick  (tick)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    // Cada tick, compara el intervalo contra el anterior (salvo el primero,
    // que solo establece la referencia).
    always @(posedge tick) begin
        if (tick_num > 0) begin
            checks = checks + 1;
            if (($time - last_tick_time) != DVSR * CLK_PERIOD) begin
                errors = errors + 1;
                $display("FAIL intervalo entre ticks = %0d ns (esperado %0d ns)",
                          $time - last_tick_time, DVSR * CLK_PERIOD);
            end else begin
                $display("OK   intervalo entre ticks = %0d ns", $time - last_tick_time);
            end
        end
        last_tick_time = $time;
        tick_num = tick_num + 1;
    end

    initial begin
        clk   = 1'b0;
        reset = 1'b1;
        tick_num = 0;

        repeat (2) @(negedge clk);
        reset = 1'b0;

        // Dejar correr suficientes ciclos para varios ticks
        #(DVSR * CLK_PERIOD * 8);

        checks = checks + 1;
        if (tick_num < 3) begin
            errors = errors + 1;
            $display("FAIL se esperaban al menos 3 ticks, se generaron %0d", tick_num);
        end else begin
            $display("OK   se generaron %0d ticks en la ventana", tick_num);
        end

        // Reset asincronico a mitad de cuenta: el conteo debe reiniciarse
        // y el periodo entre ticks debe seguir siendo DVSR ciclos.
        reset = 1'b1;
        #(CLK_PERIOD * 2 + 3); // corta el contador en un punto intermedio
        reset = 1'b0;
        tick_num = 0;

        #(DVSR * CLK_PERIOD * 4);

        checks = checks + 1;
        if (tick_num < 2) begin
            errors = errors + 1;
            $display("FAIL tras reset se esperaban al menos 2 ticks, se generaron %0d", tick_num);
        end else begin
            $display("OK   tras reset se generaron %0d ticks", tick_num);
        end

        if (errors == 0)
            $display("TEST PASSED: %0d checks, 0 errors", checks);
        else
            $display("TEST FAILED: %0d checks, %0d errors", checks, errors);

        $finish;
    end

endmodule
