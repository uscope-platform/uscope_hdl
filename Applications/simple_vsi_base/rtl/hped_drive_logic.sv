
module hped_drive_logic (
    input wire clock,
    input wire reset,
    AXI.master data_axi, 
    axi_lite.slave control_axi,
    output wire irq,

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
    input wire dc_spi_data_i
  
);

    wire pwm_sync;

    axi_lite pwm_axi();
    axi_lite gpio_axi();
    axi_lite phase_tb_axi();
    axi_lite dc_tb_axi();
    axi_lite ph_spi_axi();
    axi_lite dc_spi_axi();
    axi_lite ph_processing_axi();
    axi_lite dc_processing_axi();
    axi_lite encoder_if_axi();
    axi_lite encoder_tb_axi();
    axi_lite mmio_axi();
    axi_lite irqc_axi();
    
    parameter PWM_BASE_ADDR = 'hA0000000;
    parameter GPIO_BASE_ADDR = 'hA0010000;
    parameter PHASE_TB = 'hA0020000;
    parameter DC_TB = 'hA0030000;
    parameter PHASE_SPI = 'hA0040000;
    parameter DC_SPI = 'hA0050000;
    parameter PHASE_PROCESSING = 'hA0060000;
    parameter DC_PROCESSING = 'hA0070000;
    parameter ENCODER_IF = 'hA0080000;
    parameter ENCODER_TB = 'hA0090000;
    parameter MMIO_TB = 'hA00A0000;
    parameter IRQC = 'hA00B0000;

    

    parameter [48:0] AXI_ADDRESSES [11:0] = '{
        PWM_BASE_ADDR,
        GPIO_BASE_ADDR,
        PHASE_TB,
        DC_TB,
        PHASE_SPI,
        DC_SPI,
        PHASE_PROCESSING,
        DC_PROCESSING,
        ENCODER_IF,
        ENCODER_TB,
        MMIO_TB,
        IRQC
    }; 
    
    axil_crossbar_interface #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(49),
        .NM(1),
        .NS(12),
        .SLAVE_ADDR(AXI_ADDRESSES),
        .SLAVE_MASK('{12{32'hf0000}})
    ) control_interconnect (
        .clock(clock),
        .reset(reset),
        .slaves('{control_axi}),
        .masters({
            pwm_axi,
            gpio_axi,
            phase_tb_axi,
            dc_tb_axi,
            ph_spi_axi,
            dc_spi_axi,
            ph_processing_axi,
            dc_processing_axi,
            encoder_if_axi,
            encoder_tb_axi, 
            mmio_axi,
            irqc_axi
        })
    );
        

    wire [31:0] ctrl_word;

    gpio #(
        .INPUT_WIDTH(32),
        .OUTPUT_WIDTH(32)
    ) sim_control(
        .clock(clock),
        .reset(reset),
        .gpio_i(ctrl_word),
        .gpio_o(ctrl_word),
        .axil(gpio_axi)
    );

    wire [11:0] pwm;
    PwmGenerator #(
        .BASE_ADDRESS(PWM_BASE_ADDR),
        .N_CHANNELS(3)
    ) gen(
        .clock(clock),
        .high_resolution_clock(0),
        .fault(0),
        .reset(reset),
        .pwm_out(pwm),
        .sync_out(pwm_sync),
        .axi_in(pwm_axi)
    );

    /////////////////////////////////////////////////////////////////////
    //                       PHASE SENSING                             //
    /////////////////////////////////////////////////////////////////////

    wire ph_sensing_en, ph_sense_trg;

    enable_generator #(
        .COUNTER_WIDTH(32)
    ) ph_timebase (
        .clock(clock),
        .reset(reset),
        .gen_enable_in(ph_sensing_en),
        .enable_out(ph_sense_trg),
        .axil(phase_tb_axi)
    );

    axi_stream raw_ph_data();
    

    spi_adc_interface #(
        .N_CHANNELS(6),
        .DATAPATH_WIDTH(14),
        .REPORTED_SIZE(12),
        .PRAGMA_MKFG_MODULE_TOP("v_sense_adc"),
        .DESTINATIONS('{7,6,5,4,3,2})
    ) ph_adc (
        .clock(clock),
        .reset(reset),
        .MISO({
            ph_spi_data_v_a,
            ph_spi_data_v_b,
            ph_spi_data_v_c,
            ph_spi_data_i_a,
            ph_spi_data_i_b,
            ph_spi_data_i_c
        }),
        .SCLK(ph_spi_clk),
        .SS(ph_spi_cs),
        .sample(ph_sense_trg),
        .axi_in(ph_spi_axi),
        .data_out(raw_ph_data)
    );

    axi_stream #(.DATA_WIDTH(16)) ph_sense_fast();
    axi_stream #(.DATA_WIDTH(16)) ph_sense();


    AdcProcessing #(
        .DATA_PATH_WIDTH(16),
        .DECIMATED(0),
        .ENABLE_AVERAGE(1),
        .DATA_BLOCK_BASE_ADDR(2),
        .FAST_DATA_OFFSET(8),
        .N_CHANNELS(6),
        .OUTPUT_SIGNED(6'b000)
    ) ph_processing (
        .clock(clock),
        .reset(reset),
        .data_in(raw_ph_data),
        .fast_data_out(ph_sense_fast),
        .filtered_data_out(ph_sense),
        .axi_in(ph_processing_axi)
    );




    /////////////////////////////////////////////////////////////////////
    //                      DC LINK SENSING                            //
    /////////////////////////////////////////////////////////////////////

    wire dc_sensing_en, dc_sense_trg;

    enable_generator #(
        .COUNTER_WIDTH(32)
    ) dc_timebase (
        .clock(clock),
        .reset(reset),
        .gen_enable_in(dc_sensing_en),
        .enable_out(dc_sense_trg),
        .axil(dc_tb_axi)
    );
    
    axi_stream raw_dc_data();

    spi_adc_interface #(
        .N_CHANNELS(2),
        .DATAPATH_WIDTH(14),
        .REPORTED_SIZE(12),
        .DESTINATIONS('{8,9})
    ) dc_adc(
        .clock(clock),
        .reset(reset),
        .MISO({
            dc_spi_data_v,
            dc_spi_data_i
        }),
        .SCLK(dc_spi_clk),
        .SS(dc_spi_cs),
        .sample(dc_sense_trg),
        .axi_in(dc_spi_axi),
        .data_out(raw_dc_data)
    );


    axi_stream #(.DATA_WIDTH(16)) dc_data_fast();
    axi_stream #(.DATA_WIDTH(16)) dc_data();


    AdcProcessing #(
        .DATA_PATH_WIDTH(16),
        .DECIMATED(0),
        .DATA_BLOCK_BASE_ADDR(8),
        .FAST_DATA_OFFSET(8),
        .ENABLE_AVERAGE(1),
        .N_CHANNELS(2),
        .OUTPUT_SIGNED(2'b00),
        .PRAGMA_MKFG_DATAPOINT_NAMES("v_sense_lv,v_sense_mv"),
        .PRAGMA_MKFG_MODULE_TOP("v_dab_processor")
    ) dc_processor (
        .clock(clock),
        .reset(reset),
        .data_in(raw_dc_data),
        .fast_data_out(dc_data_fast),
        .filtered_data_out(dc_data),
        .axi_in(dc_processing_axi)
    );

    /////////////////////////////////////////////////////////////////////
    //                     ENCODER INTERFACE                           //
    /////////////////////////////////////////////////////////////////////
    wire sample_angle, sample_speed;


    axi_stream #(.DATA_WIDTH(16)) speed();
    axi_stream #(.DATA_WIDTH(16)) angle();

    encoder_interface enc_if(
        .clock(clock),
        .reset(reset),
        .a(encoder_a),
        .b(encoder_b),
        .z(encoder_index),
        .sample_angle(sample_angle),
        .sample_speed(sample_speed),
        .axi_in(encoder_if_axi),
        .angle(angle),
        .speed(speed)
    );

    enable_generator_2 #(
        .COUNTER_WIDTH(16)
    )enc_tb(
        .clock(clock),
        .reset(reset),
        .ext_timebase(0),
        .gen_enable_in(1),
        .enable_out_1(sample_angle),
        .enable_out_2(sample_speed),
        .axil(encoder_tb_axi)
    );

    axi_stream mmio_data();

    axi_stream_combiner #(
        .INPUT_DATA_WIDTH(16), 
        .OUTPUT_DATA_WIDTH(32), 
        .DEST_WIDTH(mmio_data.DEST_WIDTH), 
        .USER_WIDTH(mmio_data.USER_WIDTH),
        .N_STREAMS(6)
    )data_combiner(
        .clock(clock),
        .reset(reset),
        .stream_in('{ph_sense_fast, ph_sense, dc_data_fast, dc_data, angle, speed}),
        .stream_out(mmio_data)
    );

     hped_mmio #(
        .N_DATAPOINTS(18),
        .BASE_ADDRESS(MMIO_TB)
     ) mmio (
        .clock(clock),
        .reset(reset),
        .data_in(mmio_data),
        .axi_bus(mmio_axi)
    );


    interrupt_controller #(
        .N_INTERRUPTS(1)
    )irq_controller(
        .clock(clock),
        .reset(reset),
        .interrupt_in(pwm_sync),
        .irq(irq),
        .axi_in(irqc_axi)
    );
    
    assign gate_a = pwm[0];
    assign gate_b = pwm[1];
    assign gate_c = pwm[2];


    assign gates_en = ctrl_word[2];

    assign ph_sensing_en = ctrl_word[1];
    assign user_led_a = ph_sensing_en;

    assign dc_sensing_en = ctrl_word[0];
    assign user_led_b = dc_sensing_en;



endmodule