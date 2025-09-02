`timescale 10ns / 1ns
`include "axi_lite_BFM.svh"
`include "interfaces.svh"


import reg_maps::*;

module waveform_generator_tb();

    reg  clk, reset;

    event config_done;

    axi_lite cfg_axi();
    axi_lite_BFM axil_bfm;

    axi_stream #() data_out();


    reg trigger = 1'b0;
    initial begin
        @(config_done);
        forever begin
            trigger = 1'b0;
            #3 trigger = 1'b1;
            #1;
        end
    end

    always begin
        clk = 1'b1;
        #0.5 clk = 1'b0;
        #0.5;
    end

    waveform_generator #(
        .N_OUTPUTS(2)
    ) UUT (
        .clock(clk),
        .reset(reset),
        .trigger(trigger),
        .axi_in(cfg_axi),
        .data_out(data_out)
    );

    initial begin

        data_out.ready <= 1'b0;
        axil_bfm = new(cfg_axi, 1);
        //Initial status
        reset <=1'h1;
        #10 reset <=1'h0;
        //TESTS
        #20.5 reset <=1'h1;

        #1 axil_bfm.write(reg_maps::waveform_generator.shape, 0);
        #1 axil_bfm.write(reg_maps::waveform_generator.output_selector, 0);
        #1 axil_bfm.write(reg_maps::waveform_generator.parameter_0, $shortrealtobits(10.5));
        #1 axil_bfm.write(reg_maps::waveform_generator.parameter_1, $shortrealtobits(55.5));
        #1 axil_bfm.write(reg_maps::waveform_generator.parameter_2, 0);
        #1 axil_bfm.write(reg_maps::waveform_generator.parameter_3, 500);
        #1 axil_bfm.write(reg_maps::waveform_generator.parameter_4, 1000);
        #1 axil_bfm.write(reg_maps::waveform_generator.parameter_5, 250);
        #1 axil_bfm.write(reg_maps::waveform_generator.parameter_6, 'h38);
        
        #1 axil_bfm.write(reg_maps::waveform_generator.output_selector, 1);
        #1 axil_bfm.write(reg_maps::waveform_generator.parameter_0, $shortrealtobits(10.5));
        #1 axil_bfm.write(reg_maps::waveform_generator.parameter_1, $shortrealtobits(55.5));
        #1 axil_bfm.write(reg_maps::waveform_generator.parameter_2, 250);
        #1 axil_bfm.write(reg_maps::waveform_generator.parameter_3, 500);
        #1 axil_bfm.write(reg_maps::waveform_generator.parameter_4, 1000);
        #1 axil_bfm.write(reg_maps::waveform_generator.parameter_5, 250);
        #1 axil_bfm.write(reg_maps::waveform_generator.parameter_6, 'h38);

        #10


        #50;
        data_out.ready <= 1'b1;

        ->config_done;
    end


endmodule
