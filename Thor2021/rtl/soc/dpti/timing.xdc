
create_clock -period 16.666 -name prog_clko_pin -waveform {0.000 8.333} [get_ports prog_clko]

set_input_delay -clock [get_clocks prog_clko_pin] -min -add_delay 1.000 [get_ports {prog_d[*]}]
set_input_delay -clock [get_clocks prog_clko_pin] -max -add_delay 7.150 [get_ports {prog_d[*]}]
set_input_delay -clock [get_clocks prog_clko_pin] -min -add_delay 1.000 [get_ports prog_rxen]
set_input_delay -clock [get_clocks prog_clko_pin] -max -add_delay 7.150 [get_ports prog_rxen]
set_input_delay -clock [get_clocks prog_clko_pin] -min -add_delay 1.000 [get_ports prog_txen]
set_input_delay -clock [get_clocks prog_clko_pin] -max -add_delay 7.150 [get_ports prog_txen]
set_output_delay -clock [get_clocks prog_clko_pin] -min -add_delay 0.400 [get_ports {prog_d[*]}]
set_output_delay -clock [get_clocks prog_clko_pin] -max -add_delay 8.600 [get_ports {prog_d[*]}]
set_output_delay -clock [get_clocks prog_clko_pin] -min -add_delay 0.400 [get_ports prog_oen]
set_output_delay -clock [get_clocks prog_clko_pin] -max -add_delay 8.600 [get_ports prog_oen]
set_output_delay -clock [get_clocks prog_clko_pin] -min -add_delay 0.400 [get_ports prog_rdn]
set_output_delay -clock [get_clocks prog_clko_pin] -max -add_delay 8.600 [get_ports prog_rdn]
set_output_delay -clock [get_clocks prog_clko_pin] -min -add_delay 0.400 [get_ports prog_wrn]
set_output_delay -clock [get_clocks prog_clko_pin] -max -add_delay 8.600 [get_ports prog_wrn]

set_property IOB TRUE [get_ports {prog_d[*]}]
set_property IOB TRUE [get_ports prog_rxen]
set_property IOB TRUE [get_ports prog_txen]



