# Regenera TP_1_ALU.xpr desde cero (rtl/, tb/, constraints/) con sus tres
# simulation sets, y corre las tres simulaciones en modo batch.
#
# El .xpr generado por este script es exactamente el que esta commiteado en
# el repo (TP_1_ALU/TP_1_ALU.xpr) - para uso normal alcanza con clonar y
# abrirlo directo en Vivado, no hace falta correr este script. Sirve como
# forma reproducible de regenerarlo si se corrompe, o para validar en CI/
# batch que todo sigue compilando y simulando bien.
#
# Uso:
#   source settings64.sh   (o settings64.bat en Windows)
#   cd tps/TP_1_ALU
#   vivado -mode batch -source scripts/build_and_sim.tcl -tclargs "$(pwd)"

set src_dir [lindex $argv 0]

set proj_name "TP_1_ALU"
set part      "xc7a35tcpg236-1"

create_project $proj_name $src_dir -part $part -force

add_files -norecurse [glob $src_dir/rtl/*.v]
add_files -fileset constrs_1 -norecurse [glob $src_dir/constraints/*.xdc]
set_property top alu_top [current_fileset]
update_compile_order -fileset sources_1

# sim_1: testbench aleatorio
add_files -fileset sim_1 -norecurse [list $src_dir/tb/alu_common.vh $src_dir/tb/alu_check_one.vh $src_dir/tb/alu_tb_random.v]
set_property top alu_tb_random [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {5us} -objects [get_filesets sim_1]
update_compile_order -fileset sim_1

# sim_2: testbench de casos fijos/dirigidos
create_fileset -simset sim_2
add_files -fileset sim_2 -norecurse [list $src_dir/tb/alu_common.vh $src_dir/tb/alu_check_one.vh $src_dir/tb/alu_tb_directed.v]
set_property top alu_tb_directed [get_filesets sim_2]
set_property -name {xsim.simulate.runtime} -value {5us} -objects [get_filesets sim_2]
update_compile_order -fileset sim_2

# sim_3: testbench del wrapper alu_top (botones/switches/LEDs), sin placa.
# OJO: alu_top_tb tiene un generador de clock perpetuo (always). Con Vivado
# 2024.2 + xsim, "run all"/"run -all" sobre un diseno con clock perpetuo NO
# se detiene de forma confiable en $finish: sigue corriendo indefinidamente
# generando un .wdb gigante (se probo, crecio a cientos de MB en segundos).
# Por eso el runtime queda acotado a un valor fijo (5us, con margen sobre los
# ~256ns que tarda el test) en vez de "all", tanto aca como en el proyecto
# real para que tampoco sea un riesgo al usar la GUI.
create_fileset -simset sim_3
add_files -fileset sim_3 -norecurse [list $src_dir/tb/alu_common.vh $src_dir/tb/alu_top_tb.v]
set_property top alu_top_tb [get_filesets sim_3]
set_property -name {xsim.simulate.runtime} -value {5us} -objects [get_filesets sim_3]
update_compile_order -fileset sim_3

foreach simset_name {sim_1 sim_2 sim_3} {
    puts "\n=== Simulando $simset_name ==="
    launch_simulation -simset [get_filesets $simset_name]
    run 5us
    close_sim
}

exit
