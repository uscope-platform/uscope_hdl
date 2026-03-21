
    open_vcd dump.vcd

    log_vcd [get_objects -recursive /*]

    run 6ms

    flush_vcd
    close_vcd
    exit
