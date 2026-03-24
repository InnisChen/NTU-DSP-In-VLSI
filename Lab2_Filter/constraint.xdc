# Clock: 10ns period (100 MHz), 調整這個值來找最高頻率
create_clock -period 10.000 -name clk -waveform {0.000 5.000} [get_ports clk]

# Input delay: 半個 clock cycle
set_input_delay -clock [get_clocks *] -add_delay 5.0 \
    [get_ports {FilterIn[*] ValidIn rst_n}]

# Output delay: 半個 clock cycle
set_output_delay -clock [get_clocks *] -add_delay 5.0 \
    [get_ports {FilterOut[*] ValidOut}]