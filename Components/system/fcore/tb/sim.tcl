

# Override parameter before launch
set_property generic "EXECUTABLE=/home/vivado/hdl/public/Components/system/fcore" [get_filesets sim_1]

launch_simulation
open_vcd test.vcd
log_vcd *
run 50 us
close_vcd