`timescale 1ns / 1ps

// Baud Rate Generator: contador modulo DVSR que genera un pulso `tick` de
// un ciclo de clock de duracion, cada DVSR ciclos. Rx/Tx usan `tick` como
// habilitacion (16x oversampling), asi que DVSR = clk_freq / (baud * 16).
//
// Ej: clk=100MHz, baud=9600  -> DVSR = 100_000_000/(9600*16)  ~= 651
//     clk=100MHz, baud=19200 -> DVSR = 100_000_000/(19200*16) ~= 326
module baud_rate_gen #(
    parameter integer DVSR = 651
) (
    input  wire clk,
    input  wire reset,
    output wire tick
);

    localparam integer CNT_WIDTH = $clog2(DVSR);

    reg [CNT_WIDTH-1:0] count;

    always @(posedge clk or posedge reset) begin
        if (reset)
            count <= {CNT_WIDTH{1'b0}};
        else if (count == DVSR-1)
            count <= {CNT_WIDTH{1'b0}};
        else
            count <= count + 1'b1;
    end

    assign tick = (count == DVSR-1);

endmodule
