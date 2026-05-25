vlib work
vlog -sv ../01_RTL/cordic_pe.v
vlog -sv ../01_RTL/FinalProject.v
vlog -sv tb_FinalProject.v
vsim -c tb_FinalProject -do "run -all; quit"
