# Clock: 14ns period (71.43 MHz), 調整這個值來找最高頻率
create_clock -period 90.000 -name clk -waveform {0.000 45.000} [get_ports clk]

# Input delay
set_input_delay -clock [get_clocks *] -add_delay 5.0 \
    [get_ports -quiet {IntpIn mu rst_n}]

# Output delay
set_output_delay -clock [get_clocks *] -add_delay 5.0 \
    [get_ports -quiet {IntpOut}]
