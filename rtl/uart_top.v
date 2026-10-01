`timescale 1ns / 1ps

// Top level del TP2: cablea los 6 modulos tal como en el diagrama de la
// teoria (Baud Rate Generator -> Rx/Tx -> Interface Circuit -> ALU).
// Unicos puertos externos: clk, reset, rx, tx (los que van a la placa).
//
// DVSR por defecto = 651 -> 100MHz / (9600 baudios * 16) ~= 651, igual
// que se calculo para baud_rate_gen.v standalone.
module uart_top #(
    parameter integer DVSR    = 651,
    parameter integer WIDTH   = 8,
    parameter integer DBIT    = 8,
    parameter integer SB_TICK = 16
) (
    input  wire clk,
    input  wire reset,
    input  wire rx,
    output wire tx
);

    wire tick;
    wire rx_done, tx_done, tx_start;
    wire [DBIT-1:0] rx_d_out, tx_d_in;
    wire [7:0] r_data, w_data;
    wire rd, wr, rx_empty, tx_full;

    baud_rate_gen #(
        .DVSR(DVSR)
    ) baud_gen (
        .clk   (clk),
        .reset (reset),
        .tick  (tick)
    );

    uart_rx #(
        .DBIT    (DBIT),
        .SB_TICK (SB_TICK)
    ) rx_unit (
        .clk     (clk),
        .reset   (reset),
        .rx      (rx),
        .s_tick  (tick),
        .rx_done (rx_done),
        .d_out   (rx_d_out)
    );

    rx_interface rx_if (
        .clk      (clk),
        .reset    (reset),
        .rx_done  (rx_done),
        .d_out    (rx_d_out),
        .r_data   (r_data),
        .rd       (rd),
        .rx_empty (rx_empty)
    );

    alu_ctrl #(
        .WIDTH(WIDTH)
    ) ctrl (
        .clk      (clk),
        .reset    (reset),
        .r_data   (r_data),
        .rx_empty (rx_empty),
        .rd       (rd),
        .w_data   (w_data),
        .wr       (wr),
        .tx_full  (tx_full)
    );

    tx_interface tx_if (
        .clk      (clk),
        .reset    (reset),
        .w_data   (w_data),
        .wr       (wr),
        .tx_full  (tx_full),
        .d_in     (tx_d_in),
        .tx_start (tx_start),
        .tx_done  (tx_done)
    );

    uart_tx #(
        .DBIT    (DBIT),
        .SB_TICK (SB_TICK)
    ) tx_unit (
        .clk      (clk),
        .reset    (reset),
        .tx_start (tx_start),
        .s_tick   (tick),
        .d_in     (tx_d_in),
        .tx_done  (tx_done),
        .tx       (tx)
    );

endmodule
