vlib work
vlog -sv ../01_RTL/cordic_pe.v
vlog -sv ../01_RTL/FinalProject.v
vlog -sv tb_FinalProject_all.v
vsim -c tb_FinalProject_all -do "run -all; quit"
