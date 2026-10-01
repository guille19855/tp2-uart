`timescale 1ns / 1ps

// Transmisor UART. FSM idle -> start -> data -> stop, simetrica al Rx pero
// sin el ajuste de medio bit en START (no hay flanco externo que detectar:
// el propio Tx marca los tiempos, asi que los 4 estados duran 16 ticks).
// `tx` es un registro (no combinacional) para que la linea serie salga
// limpia, sin glitches, sincronizada a `clk`.
module uart_tx #(
    parameter integer DBIT    = 8,
    parameter integer SB_TICK = 16
) (
    input  wire             clk,
    input  wire             reset,
    input  wire             tx_start,
    input  wire             s_tick,
    input  wire [DBIT-1:0]  d_in,
    output reg              tx_done,
    output wire             tx
);

    localparam [1:0]
        IDLE  = 2'b00,
        START = 2'b01,
        DATA  = 2'b10,
        STOP  = 2'b11;

    reg [1:0]              state_reg, state_next;
    reg [3:0]              s_reg,     s_next;      // cuenta ticks dentro del bit actual (0-15)
    reg [$clog2(DBIT)-1:0] n_reg,     n_next;      // cuenta bits de datos enviados
    reg [DBIT-1:0]         b_reg,     b_next;      // shift register de datos a enviar
    reg                    tx_reg,    tx_next;     // linea de salida registrada

    // Memoria de estado
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state_reg <= IDLE;
            s_reg     <= 4'd0;
            n_reg     <= {$clog2(DBIT){1'b0}};
            b_reg     <= {DBIT{1'b0}};
            tx_reg    <= 1'b1; // linea en reposo = 1
        end else begin
            state_reg <= state_next;
            s_reg     <= s_next;
            n_reg     <= n_next;
            b_reg     <= b_next;
            tx_reg    <= tx_next;
        end
    end

    // Logica de siguiente estado y salidas
    always @(*) begin
        state_next = state_reg;
        tx_done    = 1'b0;
        s_next     = s_reg;
        n_next     = n_reg;
        b_next     = b_reg;
        tx_next    = tx_reg;

        case (state_reg)
            IDLE: begin
                tx_next = 1'b1;
                if (tx_start) begin
                    state_next = START;
                    s_next     = 4'd0;
                    b_next     = d_in;
                end
            end

            START: begin
                tx_next = 1'b0; // bit de Start
                if (s_tick) begin
                    if (s_reg == 4'd15) begin
                        state_next = DATA;
                        s_next     = 4'd0;
                        n_next     = {$clog2(DBIT){1'b0}};
                    end else begin
                        s_next = s_reg + 1'b1;
                    end
                end
            end

            DATA: begin
                tx_next = b_reg[0]; // LSB primero
                if (s_tick) begin
                    if (s_reg == 4'd15) begin
                        s_next = 4'd0;
                        b_next = b_reg >> 1;
                        if (n_reg == DBIT-1)
                            state_next = STOP;
                        else
                            n_next = n_reg + 1'b1;
                    end else begin
                        s_next = s_reg + 1'b1;
                    end
                end
            end

            STOP: begin
                tx_next = 1'b1; // bit de Stop
                if (s_tick) begin
                    if (s_reg == SB_TICK-1) begin
                        state_next = IDLE;
                        tx_done    = 1'b1;
                    end else begin
                        s_next = s_reg + 1'b1;
                    end
                end
            end

            default: state_next = IDLE; // Fault recovery
        endcase
    end

    assign tx = tx_reg;

endmodule
