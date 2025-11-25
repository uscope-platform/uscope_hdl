proc adder {name adder_latency} {
    create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name $name

    set_property -dict [list \
        CONFIG.Operation_Type {Add_Subtract} \
        CONFIG.A_TUSER_Width {32} \
        CONFIG.C_Accum_Input_Msb {15} \
        CONFIG.C_Accum_Lsb {-24} \
        CONFIG.C_Latency ${adder_latency} \
        CONFIG.C_Mult_Usage {Full_Usage} \
        CONFIG.Has_ARESETn {true} \
        CONFIG.Has_A_TUSER {true} \
        CONFIG.Has_RESULT_TREADY {false} \
        CONFIG.Flow_Control {NonBlocking} \
        CONFIG.Maximum_Latency {false}
    ] [get_ips $name]


    generate_target all [get_ips $name]
    make_wrapper -files [get_files ${name}.xci] -language SystemVerilog -add

}