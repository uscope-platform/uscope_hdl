
module simple_vsi_base (
    output wire user_led_a,
    output wire user_led_b,
    //GATES
    output wire gate_a,
    output wire gate_b,
    output wire gate_c,
    output wire gates_en,
    //ENCODER
    input wire encoder_a,
    input wire encoder_b,
    input wire encoder_index,
    // PHASES ADC
    output wire ph_spi_clk,
    output wire ph_spi_cs,
    input wire ph_spi_data_v_a,
    input wire ph_spi_data_v_b,
    input wire ph_spi_data_v_c,
    input wire ph_spi_data_i_a,
    input wire ph_spi_data_i_b,
    input wire ph_spi_data_i_c,
    //DC LINK ADC
    output wire dc_spi_clk,
    output wire dc_spi_cs,
    input wire dc_spi_data_v,
    input wire dc_spi_data_i,

    output wire pmod_1,
    output wire pmod_2,
    output wire pmod_3,
    output wire pmod_4,
    output wire pmod_5,
    output wire pmod_6,
    output wire pmod_7,
    output wire pmod_8
  
);

    wire clock, reset;
    
    axi_lite control_axi();
    AXI data_axi();

    wire irq;

    simple_vsi_PS_wrapper PS (
        .logic_clock(clock),
        .reset(reset),
        .control_axi(control_axi),
        .data_axi(data_axi),
        .dma_done(irq)
    );

        
    hped_drive_logic innards(
        .clock(clock),
        .reset(reset),
        .data_axi(data_axi),
        .control_axi(control_axi),
        .irq(irq),

        .user_led_a(user_led_a),
        .user_led_b(user_led_b),
        .gate_a(gate_a),
        .gate_b(gate_b),
        .gate_c(gate_c),
        .gates_en(gates_en),
        .encoder_a(encoder_a),
        .encoder_b(encoder_b),
        .encoder_index(encoder_index),
        .ph_spi_clk(ph_spi_clk),
        .ph_spi_cs(ph_spi_cs),
        .ph_spi_data_v_a(ph_spi_data_v_a),
        .ph_spi_data_v_b(ph_spi_data_v_b),
        .ph_spi_data_v_c(ph_spi_data_v_c),
        .ph_spi_data_i_a(ph_spi_data_i_a),
        .ph_spi_data_i_b(ph_spi_data_i_b),
        .ph_spi_data_i_c(ph_spi_data_i_c),


        .dc_spi_clk(dc_spi_clk),
        .dc_spi_cs(dc_spi_cs),
        .dc_spi_data_v(dc_spi_data_v),
        .dc_spi_data_i(dc_spi_data_i),
        .pmod_1(pmod_1),
        .pmod_2(pmod_2),
        .pmod_3(pmod_3),
        .pmod_4(pmod_4),
        .pmod_5(pmod_5),
        .pmod_6(pmod_6),
        .pmod_7(pmod_7),
        .pmod_8(pmod_8)
    
    );


endmodule