## Agrega basys3_uart.xdc como un constraint set NUEVO y separado de constrs_1
## (que es el que usa la demo alu_top del TP1), y fija uart_top como top de
## sintesis/implementacion.
if { [llength [get_filesets -quiet constrs_uart]] == 0 } {
    create_fileset -constrset constrs_uart
}
add_files -fileset constrs_uart -norecurse {C:/Users/Guillee/FACU/ARQUI/PRACTICO/TP2/constraints/basys3_uart.xdc}

set_property top uart_top [get_filesets sources_1]
update_compile_order -fileset sources_1

set_property constrset constrs_uart [get_runs synth_1]
set_property constrset constrs_uart [get_runs impl_1]

puts "constraints de uart_top agregadas OK (constrset=constrs_uart, top=uart_top)"
