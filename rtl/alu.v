`timescale 1ns / 1ps

module alu #(
    parameter WIDTH = 32
) (
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    input  wire [5:0]       op,
    output reg  [WIDTH-1:0] result,
    output wire              zero,
    output reg               carry_out,
    output reg               overflow
);

    localparam [5:0]
        OP_ADD = 6'b100000,
        OP_SUB = 6'b100010,
        OP_AND = 6'b100100,
        OP_OR  = 6'b100101,
        OP_XOR = 6'b100110,
        OP_SRA = 6'b000011,
        OP_SRL = 6'b000010,
        OP_NOR = 6'b100111;

    // SRA/SRL desplazan `a` la cantidad indicada por los bits bajos de `b`
    localparam SHAMT_BITS = $clog2(WIDTH);
    wire [SHAMT_BITS-1:0] shamt = b[SHAMT_BITS-1:0];

    wire [WIDTH:0] add_sub_ext = (op == OP_SUB) ? ({1'b0, a} - {1'b0, b})
                                                 : ({1'b0, a} + {1'b0, b});

    assign zero = (result == {WIDTH{1'b0}});

    always @(*) begin
        carry_out = 1'b0;
        overflow  = 1'b0;

        case (op)
            OP_ADD: begin
                result    = add_sub_ext[WIDTH-1:0];
                carry_out = add_sub_ext[WIDTH];
                overflow  = (a[WIDTH-1] == b[WIDTH-1]) && (result[WIDTH-1] != a[WIDTH-1]);
            end
            OP_SUB: begin
                result    = add_sub_ext[WIDTH-1:0];
                carry_out = add_sub_ext[WIDTH];
                overflow  = (a[WIDTH-1] != b[WIDTH-1]) && (result[WIDTH-1] != a[WIDTH-1]);
            end
            OP_AND:  result = a & b;
            OP_OR:   result = a | b;
            OP_XOR:  result = a ^ b;
            OP_NOR:  result = ~(a | b);
            OP_SRL:  result = a >> shamt;
            OP_SRA:  result = $signed(a) >>> shamt;
            default: result = {WIDTH{1'b0}};
        endcase
    end

endmodule
