`timescale 1ns / 1ps

module alu_top (
    input  wire       clk,
    input  wire [7:0] sw_data,
    input  wire [5:0] sw_op,
    input  wire       btn_load_a,
    input  wire       btn_load_b,
    input  wire       btn_load_op,
    output wire [7:0] led_result,
    output wire       led_zero,
    output wire       led_carry,
    output wire       led_overflow
);

    localparam DEMO_WIDTH = 8;

    reg [DEMO_WIDTH-1:0] reg_a, reg_b;
    reg [5:0]             reg_op;

    // Los switches se reutilizan para A, B y Op; cada boton confirma que el
    // valor actual de los switches se cargue en el registro correspondiente.
    always @(posedge clk) begin
        if (btn_load_a)  reg_a  <= sw_data;
        if (btn_load_b)  reg_b  <= sw_data;
        if (btn_load_op) reg_op <= sw_op;
    end

    wire [DEMO_WIDTH-1:0] alu_result;
    wire alu_zero, alu_carry, alu_overflow;

    alu #(
        .WIDTH(DEMO_WIDTH)
    ) alu_inst (
        .a         (reg_a),
        .b         (reg_b),
        .op        (reg_op),
        .result    (alu_result),
        .zero      (alu_zero),
        .carry_out (alu_carry),
        .overflow  (alu_overflow)
    );

    assign led_result   = alu_result;
    assign led_zero     = alu_zero;
    assign led_carry    = alu_carry;
    assign led_overflow = alu_overflow;

endmodule
