
set_property PACKAGE_PIN H7 [get_ports user_led_b]             ;# HPA14_N 3.3V
set_property PACKAGE_PIN G7 [get_ports user_led_a]             ;# HPA14_P 3.3V

set_property IOSTANDARD LVCMOS18 [get_ports user_led_b]
set_property IOSTANDARD LVCMOS18 [get_ports user_led_a]
 
set_property PACKAGE_PIN H10 [get_ports gate_a]                ;# HDA02 3.3V
set_property PACKAGE_PIN H9 [get_ports gate_b]                 ;# HDA03 3.3V
set_property PACKAGE_PIN G10 [get_ports gate_c]                ;# HDA04 3.3V
set_property PACKAGE_PIN G9 [get_ports gates_en]               ;# HDA05 3.3V
set_property PACKAGE_PIN E10      [get_ports encoder_index]    ;# HDA10 3.3V
set_property PACKAGE_PIN F9       [get_ports encoder_b]        ;# HDA07 3.3V
set_property PACKAGE_PIN F10      [get_ports encoder_a]        ;# HDA06 3.3V

set_property IOSTANDARD LVCMOS33 [get_ports gate_a] 
set_property IOSTANDARD LVCMOS33 [get_ports gate_b]
set_property IOSTANDARD LVCMOS33 [get_ports gate_c]
set_property IOSTANDARD LVCMOS33 [get_ports gates_en]
set_property IOSTANDARD LVCMOS33 [get_ports encoder_index]
set_property IOSTANDARD LVCMOS33 [get_ports encoder_b]
set_property IOSTANDARD LVCMOS33 [get_ports encoder_a]

set_property PACKAGE_PIN U5       [get_ports ph_spi_cs]        ;# HPA03_N 1.8V
set_property PACKAGE_PIN P6       [get_ports ph_spi_clk]       ;# HPA00_P 1.8V
set_property PACKAGE_PIN N6       [get_ports ph_spi_data_v_a]  ;# HPA00_N 1.8V
set_property PACKAGE_PIN N4       [get_ports ph_spi_data_i_a]  ;# HPA01_P 1.8V
set_property PACKAGE_PIN P4       [get_ports ph_spi_data_v_b]  ;# HPA01_N 1.8V
set_property PACKAGE_PIN M7       [get_ports ph_spi_data_i_b]  ;# HPA02_P 1.8V
set_property PACKAGE_PIN N7       [get_ports ph_spi_data_v_c]  ;# HPA02_N 1.8V
set_property PACKAGE_PIN T6       [get_ports ph_spi_data_i_c]  ;# HPA03_P 1.8V


set_property IOSTANDARD  LVCMOS18 [get_ports ph_spi_cs] 
set_property IOSTANDARD  LVCMOS18 [get_ports ph_spi_clk]
set_property IOSTANDARD  LVCMOS18 [get_ports ph_spi_data_v_a] 
set_property IOSTANDARD  LVCMOS18 [get_ports ph_spi_data_i_a] 
set_property IOSTANDARD  LVCMOS18 [get_ports ph_spi_data_v_b] 
set_property IOSTANDARD  LVCMOS18 [get_ports ph_spi_data_i_b]
set_property IOSTANDARD  LVCMOS18 [get_ports ph_spi_data_v_c] 
set_property IOSTANDARD  LVCMOS18 [get_ports ph_spi_data_i_c]

set_property PACKAGE_PIN H8       [get_ports dc_spi_clk]       ;# HPA12_P 1.8V
set_property PACKAGE_PIN K1       [get_ports dc_spi_cs]        ;# HPA13_N 1.8V
set_property PACKAGE_PIN J1       [get_ports dc_spi_data_i]    ;# HPA13_P 1.8V
set_property PACKAGE_PIN J7       [get_ports dc_spi_data_v]    ;# HPA12_N 1.8V


set_property IOSTANDARD  LVCMOS18 [get_ports dc_spi_clk]
set_property IOSTANDARD  LVCMOS18 [get_ports dc_spi_cs]
set_property IOSTANDARD  LVCMOS18 [get_ports dc_spi_data_i] 
set_property IOSTANDARD  LVCMOS18 [get_ports dc_spi_data_v] 