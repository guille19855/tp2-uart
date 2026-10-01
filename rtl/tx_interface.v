`timescale 1ns / 1ps

// Mitad "Tx" del Interface Circuit: conecta el lado ALU (w_data/wr/tx_full)
// con el lado UART (d_in/tx_start/tx_done de uart_tx.v). Guarda un byte en
// un buffer de 1 lugar y dispara la transmision.
//
// FSM de 3 estados en vez de 2 para no tener que mezclar en el mismo ciclo
// "el dato que acaba de llegar por w_data" con "el buffer ya registrado":
//   READY    (tx_full=0): acepta w_data si wr=1, pasa a START_TX.
//   START_TX (tx_full=1): buf_reg ya es valido -> dispara tx_start un ciclo.
//   BUSY     (tx_full=1): espera tx_done (fin de la transmision serie).
module tx_interface (
    input  wire       clk,
    input  wire       reset,

    // lado ALU
    input  wire [7:0] w_data,
    input  wire       wr,
    output wire       tx_full,

    // lado uart_tx
    output wire [7:0] d_in,
    output reg        tx_start,
    input  wire       tx_done
);

    localparam [1:0]
        READY    = 2'b00,
        START_TX = 2'b01,
        BUSY     = 2'b10;

    reg [1:0] state_reg, state_next;
    reg [7:0] buf_reg,   buf_next;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state_reg <= READY;
            buf_reg   <= 8'd0;
        end else begin
            state_reg <= state_next;
            buf_reg   <= buf_next;
        end
    end

    always @(*) begin
        state_next = state_reg;
        buf_next   = buf_reg;
        tx_start   = 1'b0;

        case (state_reg)
            READY: begin
                if (wr) begin
                    state_next = START_TX;
                    buf_next   = w_data;
                end
            end

            START_TX: begin
                tx_start   = 1'b1;
                state_next = BUSY;
            end

            BUSY: begin
                if (tx_done)
                    state_next = READY;
            end

            default: state_next = READY;
        endcase
    end

    assign tx_full = (state_reg != READY);
    assign d_in    = buf_reg;

endmodule
