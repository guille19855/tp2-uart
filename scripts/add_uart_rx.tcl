add_files -norecurse {C:/Users/Guillee/FACU/ARQUI/PRACTICO/TP2/rtl/uart_rx.v}
add_files -fileset sim_1 -norecurse {C:/Users/Guillee/FACU/ARQUI/PRACTICO/TP2/tb/uart_rx_tb.v}
set_property top uart_rx_tb [get_filesets sim_1]
update_compile_order -fileset sim_1
puts "uart_rx agregado OK"
