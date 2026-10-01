`timescale 1ns / 1ps

// Controlador que conecta el Interface Circuit con la ALU (alu.v, TP1,
// sin modificar). Protocolo definido para este TP2:
//
//   Host -> FPGA: 3 bytes  [opcode][operando A][operando B]
//   FPGA -> Host: 2 bytes  [result][flags]
//
//   flags = {5'b0, zero, carry_out, overflow}  (bit2=zero, bit1=carry, bit0=overflow)
//
// Requiere WIDTH<=8 para que A y B entren cada uno en 1 byte (por defecto
// WIDTH=8, igual que el demo alu_top.v del TP1).
module alu_ctrl #(
    parameter integer WIDTH = 8
) (
    input  wire       clk,
    input  wire       reset,

    // lado Interface Circuit - Rx (llegan los bytes del host)
    input  wire [7:0] r_data,
    input  wire       rx_empty,
    output reg        rd,

    // lado Interface Circuit - Tx (sale la respuesta)
    output reg  [7:0] w_data,
    output reg        wr,
    input  wire       tx_full
);

    localparam [2:0]
        WAIT_OP     = 3'd0,
        WAIT_A      = 3'd1,
        WAIT_B      = 3'd2,
        SEND_RESULT = 3'd3,
        SEND_FLAGS  = 3'd4;

    reg [2:0]       state_reg, state_next;
    reg [7:0]       op_reg,    op_next;
    reg [WIDTH-1:0] a_reg,     a_next;
    reg [WIDTH-1:0] b_reg,     b_next;

    wire [WIDTH-1:0] alu_result;
    wire             alu_zero, alu_carry, alu_overflow;

    alu #(
        .WIDTH(WIDTH)
    ) alu_inst (
        .a         (a_reg),
        .b         (b_reg),
        .op        (op_reg[5:0]),
        .result    (alu_result),
        .zero      (alu_zero),
        .carry_out (alu_carry),
        .overflow  (alu_overflow)
    );

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state_reg <= WAIT_OP;
            op_reg    <= 8'd0;
            a_reg     <= {WIDTH{1'b0}};
            b_reg     <= {WIDTH{1'b0}};
        end else begin
            state_reg <= state_next;
            op_reg    <= op_next;
            a_reg     <= a_next;
            b_reg     <= b_next;
        end
    end

    always @(*) begin
        state_next = state_reg;
        op_next    = op_reg;
        a_next     = a_reg;
        b_next     = b_reg;
        rd         = 1'b0;
        wr         = 1'b0;
        w_data     = 8'd0;

        case (state_reg)
            WAIT_OP: begin
                if (!rx_empty) begin
                    rd         = 1'b1;
                    op_next    = r_data;
                    state_next = WAIT_A;
                end
            end

            WAIT_A: begin
                if (!rx_empty) begin
                    rd         = 1'b1;
                    a_next     = r_data[WIDTH-1:0];
                    state_next = WAIT_B;
                end
            end

            WAIT_B: begin
                if (!rx_empty) begin
                    rd         = 1'b1;
                    b_next     = r_data[WIDTH-1:0];
                    state_next = SEND_RESULT;
                end
            end

            SEND_RESULT: begin
                if (!tx_full) begin
                    wr         = 1'b1;
                    w_data     = alu_result;
                    state_next = SEND_FLAGS;
                end
            end

            SEND_FLAGS: begin
                if (!tx_full) begin
                    wr         = 1'b1;
                    w_data     = {5'b0, alu_zero, alu_carry, alu_overflow};
                    state_next = WAIT_OP;
                end
            end

            default: state_next = WAIT_OP;
        endcase
    end

endmodule
