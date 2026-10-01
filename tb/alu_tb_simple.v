`timescale 1ns / 1ps

// Testbench minimo y autocontenido para alu.v (sin includes ni tasks
// compartidas con los otros tb). Pensado para correrse rapido, por ejemplo
// con iverilog:
//   iverilog -o sim.out ../rtl/alu.v alu_tb_simple.v && vvp sim.out

module alu_tb_simple;

    localparam WIDTH = 8;

    localparam [5:0]
        OP_ADD = 6'b100000,
        OP_SUB = 6'b100010,
        OP_AND = 6'b100100,
        OP_OR  = 6'b100101,
        OP_XOR = 6'b100110,
        OP_SRA = 6'b000011,
        OP_SRL = 6'b000010,
        OP_NOR = 6'b100111;

    reg  [WIDTH-1:0] a, b;
    reg  [5:0]       op;
    wire [WIDTH-1:0] result;
    wire             zero, carry_out, overflow;

    integer errors = 0;
    integer checks = 0;

    alu #(
        .WIDTH(WIDTH)
    ) dut (
        .a         (a),
        .b         (b),
        .op        (op),
        .result    (result),
        .zero      (zero),
        .carry_out (carry_out),
        .overflow  (overflow)
    );

    // Aplica un caso y compara contra los valores esperados pasados a mano
    task automatic check(
        input [WIDTH-1:0] ta, tb_,
        input [5:0]       top,
        input [WIDTH-1:0] exp_result,
        input             exp_zero, exp_carry, exp_overflow
    );
        begin
            a = ta; b = tb_; op = top;
            #10; // deja asentar la logica combinacional

            checks = checks + 1;
            if (result !== exp_result || zero !== exp_zero ||
                carry_out !== exp_carry || overflow !== exp_overflow) begin
                errors = errors + 1;
                $display("FAIL op=%b a=%h b=%h | got result=%h zero=%b carry=%b ovf=%b | expected result=%h zero=%b carry=%b ovf=%b",
                          top, ta, tb_, result, zero, carry_out, overflow,
                          exp_result, exp_zero, exp_carry, exp_overflow);
            end else begin
                $display("OK   op=%b a=%h b=%h -> result=%h zero=%b carry=%b ovf=%b",
                          top, ta, tb_, result, zero, carry_out, overflow);
            end
        end
    endtask

    initial begin
        // ADD: caso simple, con carry, con overflow con signo
        check(8'd10,  8'd20,  OP_ADD, 8'd30,  1'b0, 1'b0, 1'b0);
        check(8'hFF,  8'h01,  OP_ADD, 8'h00,  1'b1, 1'b1, 1'b0); // carry + zero
        check(8'h7F,  8'h01,  OP_ADD, 8'h80,  1'b0, 1'b0, 1'b1); // overflow positivo

        // SUB: resultado cero, y borrow cuando a < b
        check(8'd20,  8'd10,  OP_SUB, 8'd10,  1'b0, 1'b0, 1'b0);
        check(8'd10,  8'd10,  OP_SUB, 8'd0,   1'b1, 1'b0, 1'b0);
        check(8'd5,   8'd10,  OP_SUB, 8'hFB,  1'b0, 1'b1, 1'b0); // borrow

        // Logicas bit a bit
        check(8'hAA,  8'h55,  OP_AND, 8'h00,  1'b1, 1'b0, 1'b0);
        check(8'hAA,  8'h55,  OP_OR,  8'hFF,  1'b0, 1'b0, 1'b0);
        check(8'hAA,  8'h55,  OP_XOR, 8'hFF,  1'b0, 1'b0, 1'b0);
        check(8'hFF,  8'hFF,  OP_NOR, 8'h00,  1'b1, 1'b0, 1'b0);

        // Shifts: logico rellena con 0, aritmetico extiende el signo
        check(8'h81,  8'd1,   OP_SRL, 8'h40,  1'b0, 1'b0, 1'b0);
        check(8'h81,  8'd1,   OP_SRA, 8'hC0,  1'b0, 1'b0, 1'b0);

        if (errors == 0)
            $display("TEST PASSED: %0d checks, 0 errors", checks);
        else
            $display("TEST FAILED: %0d checks, %0d errors", checks, errors);

        $finish;
    end

endmodule
