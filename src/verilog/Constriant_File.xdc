create_clock -period 10.000 -name clk -waveform {0.000 5.000} [get_ports clk]
set_input_delay -clock [get_clocks clk] -min -add_delay 0.200 [get_ports rst]
set_input_delay -clock [get_clocks clk] -max -add_delay 0.200 [get_ports rst]
set_input_delay -clock [get_clocks clk] -min -add_delay 0.200 [get_ports rx]
set_input_delay -clock [get_clocks clk] -max -add_delay 0.200 [get_ports rx]
#set_output_delay -clock [get_clocks clk] -min -add_delay 0.000 [get_ports rx_ready]
#set_output_delay -clock [get_clocks clk] -max -add_delay 0.200 [get_ports rx_ready]
set_output_delay -clock [get_clocks clk] -min -add_delay 0.000 [get_ports tx]
set_output_delay -clock [get_clocks clk] -max -add_delay 0.200 [get_ports tx]
#set_output_delay -clock [get_clocks clk] -min -add_delay 0.000 [get_ports tx_busy]
#set_output_delay -clock [get_clocks clk] -max -add_delay 0.200 [get_ports tx_busy]
set_property PACKAGE_PIN E3 [get_ports clk]
set_property PACKAGE_PIN N17 [get_ports rst]
set_property PACKAGE_PIN C4 [get_ports rx]
set_property PACKAGE_PIN D4 [get_ports tx]
#set_property PACKAGE_PIN K15 [get_ports rx_ready]
#set_property PACKAGE_PIN H17 [get_ports tx_busy]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports rst]
set_property IOSTANDARD LVCMOS33 [get_ports rx]
#set_property IOSTANDARD LVCMOS33 [get_ports rx_ready]
set_property IOSTANDARD LVCMOS33 [get_ports tx]
#set_property IOSTANDARD LVCMOS33 [get_ports tx_busy]
