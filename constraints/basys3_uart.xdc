## Constraints UART para uart_top.v en la Digilent Basys3 (xc7a35tcpg236-1)
##
## clk   -> W5   (reloj de 100 MHz)
## reset -> U18  (BTNC, boton central)
## rx    -> B18  (lo que el FPGA RECIBE, via el puente USB-UART del cable de programacion)
## tx    -> A18  (lo que el FPGA TRANSMITE, via el mismo puente USB-UART)

## Reloj de 100 MHz
set_property -dict { PACKAGE_PIN W5  IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -period 10.000 -name sys_clk [get_ports { clk }];

## Reset (BTNC, boton central)
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports { reset }];

## UART (puente USB-UART integrado en el cable de programacion)
set_property -dict { PACKAGE_PIN B18 IOSTANDARD LVCMOS33 } [get_ports { rx }];
set_property -dict { PACKAGE_PIN A18 IOSTANDARD LVCMOS33 } [get_ports { tx }];
