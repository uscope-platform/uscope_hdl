proc fti {name fti_latency} {
    create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name $name

    set_property -dict [list \
        CONFIG.A_TUSER_Width {32} \
        CONFIG.C_Latency ${fti_latency} \
        CONFIG.C_Result_Exponent_Width {32} \
        CONFIG.C_Result_Fraction_Width {0} \
        CONFIG.Flow_Control {NonBlocking} \
        CONFIG.Has_ARESETn {true} \
        CONFIG.Has_A_TUSER {true} \
        CONFIG.Has_RESULT_TREADY {false} \
        CONFIG.Maximum_Latency {false} \
        CONFIG.Operation_Type {Float_to_fixed} \
        CONFIG.Result_Precision_Type {Int32} \
    ] [get_ips $name]


    generate_target all [get_ips $name]
    make_wrapper -files [get_files ${name}.xci] -language SystemVerilog -add

}