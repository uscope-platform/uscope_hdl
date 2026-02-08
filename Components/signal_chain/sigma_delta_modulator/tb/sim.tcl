
open_vcd dump.vcd

log_vcd [get_objects -recursive /*]

run 2ms

flush_vcd
close_vcd
exit