`timescale 1ns / 1ps

// Mitad "Rx" del Interface Circuit: conecta el lado UART (rx_done/d_out de
// uart_rx.v) con el lado ALU (r_data/rd/rx_empty). A diferencia de
// tx_interface.v, aca la transaccion la dispara el receptor (rx_done es
// asincrono respecto a lo que hace la ALU), no un pedido explicito.
//
// FSM de 2 estados (no hace falta un estado intermedio como START_TX,
// porque no hay nada que disparar, solo capturar):
//   EMPTY (rx_empty=1): espera rx_done para capturar d_out.
//   FULL  (rx_empty=0): espera rd de la ALU para liberar el buffer.
//
// Politica de overrun (decision de diseno): si llega un rx_done nuevo
// estando en FULL (la ALU todavia no leyo el byte anterior), el dato
// nuevo PISA al viejo no leido, y se queda en FULL. Es la politica mas
// simple con un buffer de 1 lugar; una FIFO evitaria esta perdida de
// datos pero agrega complejidad que este TP no pide.
module rx_interface (
    input  wire       clk,
    input  wire       reset,

    // lado uart_rx
    input  wire       rx_done,
    input  wire [7:0] d_out,

    // lado ALU
    output wire [7:0] r_data,
    input  wire       rd,
    output wire       rx_empty
);

    localparam EMPTY = 1'b0,
               FULL  = 1'b1;

    reg state_reg, state_next;
    reg [7:0] buf_reg, buf_next;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state_reg <= EMPTY;
            buf_reg   <= 8'd0;
        end else begin
            state_reg <= state_next;
            buf_reg   <= buf_next;
        end
    end

    always @(*) begin
        state_next = state_reg;
        buf_next   = buf_reg;

        case (state_reg)
            EMPTY: begin
                if (rx_done) begin
                    state_next = FULL;
                    buf_next   = d_out;
                end
            end

            FULL: begin
                if (rx_done) begin
                    // overrun: pisa el dato no leido, se queda en FULL
                    buf_next = d_out;
                end else if (rd) begin
                    state_next = EMPTY;
                end
            end

            default: state_next = EMPTY;
        endcase
    end

    assign rx_empty = (state_reg == EMPTY);
    assign r_data   = buf_reg;

endmodule
