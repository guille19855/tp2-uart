`timescale 1ns / 1ps

// Receptor UART. FSM idle -> start -> data -> stop (ver diagrama de
// estados Rx en la teoria del TP2). `s_tick` es el tick a 16x baud rate
// que entrega baud_rate_gen. `DBIT` bits de datos (LSB primero),
// `SB_TICK` ticks de bit de Stop (16 ticks = 1 bit de Stop).
module uart_rx #(
    parameter integer DBIT    = 8,
    parameter integer SB_TICK = 16
) (
    input  wire       clk,
    input  wire       reset,
    input  wire       rx,
    input  wire       s_tick,
    output reg        rx_done,
    output wire [DBIT-1:0] d_out
);

    localparam [1:0]
        IDLE  = 2'b00,
        START = 2'b01,
        DATA  = 2'b10,
        STOP  = 2'b11;

    reg [1:0]           state_reg,  state_next;
    reg [3:0]           s_reg,      s_next;      // cuenta ticks dentro del bit actual (0-15)
    reg [$clog2(DBIT)-1:0] n_reg,   n_next;      // cuenta bits de datos recibidos
    reg [DBIT-1:0]      b_reg,      b_next;      // shift register de datos

    // Memoria de estado
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state_reg <= IDLE;
            s_reg     <= 4'd0;
            n_reg     <= {$clog2(DBIT){1'b0}};
            b_reg     <= {DBIT{1'b0}};
        end else begin
            state_reg <= state_next;
            s_reg     <= s_next;
            n_reg     <= n_next;
            b_reg     <= b_next;
        end
    end

    // Logica de siguiente estado y salidas (Mealy: rx_done_tick)
    always @(*) begin
        state_next = state_reg;
        rx_done    = 1'b0;
        s_next     = s_reg;
        n_next     = n_reg;
        b_next     = b_reg;

        case (state_reg)
            IDLE: begin
                if (~rx) begin
                    state_next = START;
                    s_next     = 4'd0;
                end
            end

            START: begin
                if (s_tick) begin
                    if (s_reg == 4'd7) begin
                        state_next = DATA;
                        s_next     = 4'd0;
                        n_next     = {$clog2(DBIT){1'b0}};
                    end else begin
                        s_next = s_reg + 1'b1;
                    end
                end
            end

            DATA: begin
                if (s_tick) begin
                    if (s_reg == 4'd15) begin
                        s_next = 4'd0;
                        b_next = {rx, b_reg[DBIT-1:1]};
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
                if (s_tick) begin
                    if (s_reg == SB_TICK-1) begin
                        state_next = IDLE;
                        rx_done    = 1'b1;
                    end else begin
                        s_next = s_reg + 1'b1;
                    end
                end
            end

            default: state_next = IDLE; // Fault recovery
        endcase
    end

    assign d_out = b_reg;

endmodule
