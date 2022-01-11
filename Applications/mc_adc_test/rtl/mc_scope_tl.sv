// Copyright 2021 University of Nottingham Ningbo China
// Author: Filippo Savi <filssavi@gmail.com>
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
`timescale 10ns / 1ns
`include "interfaces.svh"

module mc_scope_tl #(parameter BASE_ADDRESS = 'h43c00000)(
    input wire clock,
    input wire reset,
    input wire dma_done,
    input wire enable,
    input wire [5:0] MISO,
    output wire SS,
    output wire SCLK,
    axi_lite dma_axi,
    axi_stream.master out,
    axi_lite.slave axi_in
);

    localparam N_CHANNELS = 6;
    localparam CHANNEL_BUFFER_SIZE = 1024; 
    localparam DATA_GEN = "TRUE";

    wire [31:0] ch_1_data;
    wire [31:0] ch_2_data;
    wire [31:0] ch_3_data;
    wire [31:0] ch_4_data;
    wire [31:0] ch_5_data;
    wire [31:0] ch_6_data;
    wire ch_1_valid, ch_2_valid, ch_3_valid, ch_4_valid, ch_5_valid, ch_6_valid;
    
    axi_stream ch_1();
    axi_stream ch_2();
    axi_stream ch_3();
    axi_stream ch_4();
    axi_stream ch_5();
    axi_stream ch_6();
    axi_stream ch_7();
    axi_stream ch_8();

    reg [31:0] latched_ch_1_data;
    reg [31:0] latched_ch_2_data;
    reg [31:0] latched_ch_3_data;
    reg [31:0] latched_ch_4_data;
    reg [31:0] latched_ch_5_data;
    reg [31:0] latched_ch_6_data;
    reg latched_ch_1_valid, latched_ch_2_valid, latched_ch_3_valid, latched_ch_4_valid, latched_ch_5_valid, latched_ch_6_valid;

    wire [31:0] counter;


    localparam SCOPE_BASE = 32'h43C01000;
    localparam ADC_BASE   = 32'h43C01100;

    axi_lite #(.INTERFACE_NAME("SCOPE")) scope_axi();
    axi_lite #(.INTERFACE_NAME("ADC")) adc_axi();


    axil_crossbar_interface #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(32),
        .NM(1),
        .NS(2),
        .SLAVE_ADDR('{SCOPE_BASE, ADC_BASE}),
        .SLAVE_MASK('{2{32'h0f000}})
    ) axi_xbar (
        .clock(clock),
        .reset(reset),
        .slaves('{axi_in}),
        .masters('{scope_axi, adc_axi})
    );

    generate 
        if(DATA_GEN=="TRUE") begin
            Data_source_wrapper data_gen(
                .aclk_0(clock & enable),
                .channel_1_tdata(ch_1_data),
                .channel_1_tvalid(ch_1_valid),
                .channel_2_tdata(ch_2_data),
                .channel_2_tvalid(ch_2_valid),
                .channel_3_tdata(ch_3_data),
                .channel_3_tvalid(ch_3_valid),
                .channel_4_tdata(ch_4_data),
                .channel_4_tvalid(ch_4_valid),
                .channel_5_tdata(ch_5_data),
                .channel_5_tvalid(ch_5_valid),
                .channel_6_tdata(ch_6_data),
                .channel_6_tvalid(ch_6_valid)
            );
        end else begin

            axi_stream samples [N_CHANNELS]();

            assign ch_1_data = samples[0].data;
            assign ch_2_data = samples[1].data;
            assign ch_3_data = samples[2].data;
            assign ch_4_data = samples[3].data;
            assign ch_5_data = samples[4].data;
            assign ch_6_data = samples[5].data;

            assign ch_1_valid = samples[0].valid;
            assign ch_2_valid = samples[1].valid;
            assign ch_3_valid = samples[2].valid;
            assign ch_4_valid = samples[3].valid;
            assign ch_5_valid = samples[4].valid;
            assign ch_6_valid = samples[5].valid;

            defparam ADC.SPI_ADDRESS = 'h43c00300;
            defparam ADC.DECIMATE = 0;
            defparam ADC.ADC_DATA_WIDTH = 14;
            SicDriveMasterAdc ADC(
                .clock(clock),
                .reset(reset),
                .ss(SS),
                .sclk(SCLK),
                .miso(MISO),
                .enable_adc(counter==32),
                .adc_samples(samples),
                .axi_in(adc_axi)
            );
        end
    endgenerate

    
    enable_generator_counter ctr(
        .clock(clock),
        .reset(reset),
        .gen_enable_in(enable),
        .period(833),
        .counter_out(counter)
    );
    
    always_ff @(posedge clock) begin
        ch_1.dest <= 0;
        ch_2.dest <= 1;
        ch_3.dest <= 2;
        ch_4.dest <= 3;
        ch_5.dest <= 4;
        ch_6.dest <= 5;
       if(counter == 10)begin
           ch_1.data <= ch_1_data;
           ch_1.valid <= 1;
       end else if(counter == 12)begin
           ch_2.data <= ch_2_data;
           ch_2.valid <= 1;
       end else if(counter == 14)begin
           ch_3.data <= ch_3_data;
           ch_3.valid <= 1;
       end else if(counter == 16)begin
           ch_4.data <= ch_4_data;
           ch_4.valid <= 1;
       end else if(counter == 18)begin
           ch_5.data <= ch_5_data;
           ch_5.valid <= 1;
       end else if(counter == 20)begin
           ch_6.data <= ch_6_data;
           ch_6.valid <= 1;
       end else begin
           ch_1.valid <= 0;
           ch_2.valid <= 0;
           ch_3.valid <= 0;
           ch_4.valid <= 0;
           ch_5.valid <= 0;
           ch_6.valid <= 0;
       end
        
    end
    
    defparam scope.BASE_ADDRESS = 'h43c00100;
    uScope scope (
        .clock(clock),
        .reset(reset),
        .dma_done(dma_done),
        .in_1(ch_1),
        .in_2(ch_2),
        .in_3(ch_3),
        .in_4(ch_4),
        .in_5(ch_5),
        .in_6(ch_6),
        .in_7(ch_7),
        .in_8(ch_8),
        .dma_axi(dma_axi),
        .out(out),
        .axi_in(scope_axi)
    );

endmodule