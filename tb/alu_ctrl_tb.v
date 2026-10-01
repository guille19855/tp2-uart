`timescale 1ns / 1ps

// Testbench autocontenido para alu_ctrl.v. No usa uart_rx/uart_tx ni las
// interfaces reales (ya estan validadas por separado) - en su lugar
// simula directamente el lado Interface Circuit con r_data/rx_empty/rd y
// w_data/wr/tx_full, para probar SOLO la logica del controlador y su
// conexion con la ALU.
//
// Los casos de ALU son los mismos que tb/alu_tb_simple.v (TP1), asi los
// resultados esperados ya estan verificados contra alu.v.
//   iverilog -o sim.out ../rtl/alu.v ../rtl/alu_ctrl.v alu_ctrl_tb.v && vvp sim.out

module alu_ctrl_tb;

    localparam integer WIDTH = 8;

    localparam [5:0]
        OP_ADD = 6'b100000,
        OP_SUB = 6'b100010,
        OP_AND = 6'b100100,
        OP_OR  = 6'b100101,
        OP_XOR = 6'b100110,
        OP_SRA = 6'b000011,
        OP_SRL = 6'b000010,
        OP_NOR = 6'b100111;

    reg clk, reset;
    reg  [7:0] r_data;
    reg        rx_empty;
    wire       rd;
    wire [7:0] w_data;
    wire       wr;
    reg        tx_full;

    integer errors = 0;
    integer checks = 0;

    alu_ctrl #(
        .WIDTH(WIDTH)
    ) dut (
        .clk      (clk),
        .reset    (reset),
        .r_data   (r_data),
        .rx_empty (rx_empty),
        .rd       (rd),
        .w_data   (w_data),
        .wr       (wr),
        .tx_full  (tx_full)
    );

    always #5 clk = ~clk;

    // Simula la llegada de los 3 bytes de un pedido, uno por ciclo (el
    // controlador los consume a la misma velocidad que se le ofrecen).
    task automatic send_op(input [7:0] op_byte, input [7:0] a_byte, input [7:0] b_byte);
        begin
            rx_empty = 1'b0;
            r_data   = op_byte;
            @(posedge clk);
            r_data = a_byte;
            @(posedge clk);
            r_data = b_byte;
            @(posedge clk);
            rx_empty = 1'b1;
        end
    endtask

    // Espera un pulso de wr (con timeout) y captura w_data en ese ciclo.
    task automatic wait_for_wr(output reg [7:0] captured, output reg ok);
        integer w;
        reg done;
        begin
            ok   = 1'b0;
            done = 1'b0;
            w    = 0;
            while (!done && w < 20) begin
                @(posedge clk);
                if (wr) begin
                    captured = w_data;
                    ok       = 1'b1;
                    done     = 1'b1;
                end
                w = w + 1;
            end
        end
    endtask

    task automatic check_op(
        input [5:0] op, input [7:0] a, input [7:0] b,
        input [7:0] exp_result, input exp_zero, input exp_carry, input exp_overflow
    );
        reg [7:0] got_result, got_flags;
        reg ok1, ok2;
        integer local_errors;
        begin
            local_errors = 0;
            checks = checks + 1;

            send_op({2'b00, op}, a, b);

            wait_for_wr(got_result, ok1);
            if (!ok1) begin
                local_errors = local_errors + 1;
                $display("FAIL op=%b a=%h b=%h: nunca llego el byte de resultado", op, a, b);
            end

            wait_for_wr(got_flags, ok2);
            if (!ok2) begin
                local_errors = local_errors + 1;
                $display("FAIL op=%b a=%h b=%h: nunca llego el byte de banderas", op, a, b);
            end

            if (ok1 && ok2) begin
                if (got_result !== exp_result) begin
                    local_errors = local_errors + 1;
                    $display("FAIL op=%b a=%h b=%h: result=%h esperado=%h", op, a, b, got_result, exp_result);
                end
                if (got_flags !== {5'b0, exp_zero, exp_carry, exp_overflow}) begin
                    local_errors = local_errors + 1;
                    $display("FAIL op=%b a=%h b=%h: flags=%b esperado=%b", op, a, b,
                              got_flags, {5'b0, exp_zero, exp_carry, exp_overflow});
                end
            end

            if (local_errors == 0)
                $display("OK   op=%b a=%h b=%h -> result=%h flags(z,c,v)=%b%b%b",
                          op, a, b, got_result, exp_zero, exp_carry, exp_overflow);
            else
                errors = errors + 1;
        end
    endtask

    initial begin
        clk      = 1'b0;
        reset    = 1'b1;
        rx_empty = 1'b1;
        r_data   = 8'd0;
        tx_full  = 1'b0;
        repeat (4) @(negedge clk);
        reset = 1'b0;
        @(posedge clk);

        // Mismos vectores que tb/alu_tb_simple.v (TP1)
        check_op(OP_ADD, 8'd10,  8'd20,  8'd30,  1'b0, 1'b0, 1'b0);
        check_op(OP_ADD, 8'hFF,  8'h01,  8'h00,  1'b1, 1'b1, 1'b0);
        check_op(OP_ADD, 8'h7F,  8'h01,  8'h80,  1'b0, 1'b0, 1'b1);
        check_op(OP_SUB, 8'd20,  8'd10,  8'd10,  1'b0, 1'b0, 1'b0);
        check_op(OP_SUB, 8'd10,  8'd10,  8'd0,   1'b1, 1'b0, 1'b0);
        check_op(OP_SUB, 8'd5,   8'd10,  8'hFB,  1'b0, 1'b1, 1'b0);
        check_op(OP_AND, 8'hAA,  8'h55,  8'h00,  1'b1, 1'b0, 1'b0);
        check_op(OP_OR,  8'hAA,  8'h55,  8'hFF,  1'b0, 1'b0, 1'b0);
        check_op(OP_XOR, 8'hAA,  8'h55,  8'hFF,  1'b0, 1'b0, 1'b0);
        check_op(OP_NOR, 8'hFF,  8'hFF,  8'h00,  1'b1, 1'b0, 1'b0);
        check_op(OP_SRL, 8'h81,  8'd1,   8'h40,  1'b0, 1'b0, 1'b0);
        check_op(OP_SRA, 8'h81,  8'd1,   8'hC0,  1'b0, 1'b0, 1'b0);

        // Backpressure: tx_full en 1 un rato antes de liberarse; el
        // controlador debe esperar (sin escribir) y recien escribir bien
        // apenas se libera. Secuencial, sin fork, para no depender de
        // tareas anidadas corriendo en paralelo.
        begin : backpressure_test
            reg [7:0] got_result, got_flags;
            reg ok1, ok2;
            integer k;

            checks = checks + 1;
            send_op({2'b00, OP_ADD}, 8'd1, 8'd1);

            tx_full = 1'b1;
            for (k = 0; k < 5; k = k + 1) begin
                @(posedge clk);
                if (wr) begin
                    errors = errors + 1;
                    $display("FAIL backpressure: escribio con tx_full en 1");
                end
            end
            tx_full = 1'b0;

            wait_for_wr(got_result, ok1);
            wait_for_wr(got_flags, ok2);

            if (!ok1 || !ok2) begin
                errors = errors + 1;
                $display("FAIL backpressure: nunca llego a escribir tras liberar tx_full");
            end else if (got_result !== 8'd2 || got_flags !== 8'b0) begin
                errors = errors + 1;
                $display("FAIL backpressure: result=%h flags=%b (esperado result=02 flags=000)", got_result, got_flags);
            end else begin
                $display("OK   backpressure: espero con tx_full=1 y escribio bien al liberarse");
            end
        end

        if (errors == 0)
            $display("TEST PASSED: %0d checks, 0 errors", checks);
        else
            $display("TEST FAILED: %0d checks, %0d errors", checks, errors);

        $finish;
    end

endmodule
