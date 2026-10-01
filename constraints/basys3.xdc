## Mapeo de pines para alu_top.v en la Digilent Basys3 (xc7a35tcpg236-1)
##
## SW0-SW7   -> sw_data[7:0]  (dato a cargar en A o B)
## SW8-SW13  -> sw_op[5:0]    (codigo de operacion a cargar)
## BTNU      -> btn_load_a    (carga sw_data en A)
## BTNL      -> btn_load_b    (carga sw_data en B)
## BTNR      -> btn_load_op   (carga sw_op en Op)
## LED0-LED7 -> led_result[7:0]
## LED8      -> led_zero
## LED9      -> led_carry
## LED10     -> led_overflow

## Reloj de 100 MHz
set_property -dict { PACKAGE_PIN W5  IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -period 10.000 -name sys_clk [get_ports { clk }];

## Switches: dato (sw_data[7:0] = SW0-SW7)
set_property -dict { PACKAGE_PIN V17 IOSTANDARD LVCMOS33 } [get_ports { sw_data[0] }];
set_property -dict { PACKAGE_PIN V16 IOSTANDARD LVCMOS33 } [get_ports { sw_data[1] }];
set_property -dict { PACKAGE_PIN W16 IOSTANDARD LVCMOS33 } [get_ports { sw_data[2] }];
set_property -dict { PACKAGE_PIN W17 IOSTANDARD LVCMOS33 } [get_ports { sw_data[3] }];
set_property -dict { PACKAGE_PIN W15 IOSTANDARD LVCMOS33 } [get_ports { sw_data[4] }];
set_property -dict { PACKAGE_PIN V15 IOSTANDARD LVCMOS33 } [get_ports { sw_data[5] }];
set_property -dict { PACKAGE_PIN W14 IOSTANDARD LVCMOS33 } [get_ports { sw_data[6] }];
set_property -dict { PACKAGE_PIN W13 IOSTANDARD LVCMOS33 } [get_ports { sw_data[7] }];

## Switches: codigo de operacion (sw_op[5:0] = SW8-SW13)
set_property -dict { PACKAGE_PIN V2  IOSTANDARD LVCMOS33 } [get_ports { sw_op[0] }];
set_property -dict { PACKAGE_PIN T3  IOSTANDARD LVCMOS33 } [get_ports { sw_op[1] }];
set_property -dict { PACKAGE_PIN T2  IOSTANDARD LVCMOS33 } [get_ports { sw_op[2] }];
set_property -dict { PACKAGE_PIN R3  IOSTANDARD LVCMOS33 } [get_ports { sw_op[3] }];
set_property -dict { PACKAGE_PIN W2  IOSTANDARD LVCMOS33 } [get_ports { sw_op[4] }];
set_property -dict { PACKAGE_PIN U1  IOSTANDARD LVCMOS33 } [get_ports { sw_op[5] }];

## Botones de carga
set_property -dict { PACKAGE_PIN T18 IOSTANDARD LVCMOS33 } [get_ports { btn_load_a  }]; ## BTNU
set_property -dict { PACKAGE_PIN W19 IOSTANDARD LVCMOS33 } [get_ports { btn_load_b  }]; ## BTNL
set_property -dict { PACKAGE_PIN T17 IOSTANDARD LVCMOS33 } [get_ports { btn_load_op }]; ## BTNR

## LEDs: resultado (led_result[7:0] = LED0-LED7)
set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33 } [get_ports { led_result[0] }];
set_property -dict { PACKAGE_PIN E19 IOSTANDARD LVCMOS33 } [get_ports { led_result[1] }];
set_property -dict { PACKAGE_PIN U19 IOSTANDARD LVCMOS33 } [get_ports { led_result[2] }];
set_property -dict { PACKAGE_PIN V19 IOSTANDARD LVCMOS33 } [get_ports { led_result[3] }];
set_property -dict { PACKAGE_PIN W18 IOSTANDARD LVCMOS33 } [get_ports { led_result[4] }];
set_property -dict { PACKAGE_PIN U15 IOSTANDARD LVCMOS33 } [get_ports { led_result[5] }];
set_property -dict { PACKAGE_PIN U14 IOSTANDARD LVCMOS33 } [get_ports { led_result[6] }];
set_property -dict { PACKAGE_PIN V14 IOSTANDARD LVCMOS33 } [get_ports { led_result[7] }];

## LEDs: banderas
set_property -dict { PACKAGE_PIN V13 IOSTANDARD LVCMOS33 } [get_ports { led_zero     }]; ## LED8
set_property -dict { PACKAGE_PIN V3  IOSTANDARD LVCMOS33 } [get_ports { led_carry    }]; ## LED9
set_property -dict { PACKAGE_PIN W3  IOSTANDARD LVCMOS33 } [get_ports { led_overflow }]; ## LED10
