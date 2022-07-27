create_clock -period 5 -name clock -waveform {0.000 2.500} [get_ports clock]

set_property PACKAGE_PIN Y6 [get_ports clock]

