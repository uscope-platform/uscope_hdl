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

module MC_scope_test_top(
    input wire A_SDO_01,
    input wire A_SDO_04,
    input wire A_SDO_05,
    input wire A_SDO_06,
    input wire A_SDO_07,
    input wire A_SDO_08,
    output wire A_SCLK_0508,
    output wire A_CONV_0508,
    output wire A_SCLK_0104,
    output wire A_CONV_0104
);
    

    wire [7:0] gpio;

    wire uscope_valid, uscope_ready, uscope_tlast, data_gen_en;
    wire [31:0] uscope_data;
    
    axi_stream ch_1();
    axi_stream ch_2();
    axi_stream ch_3();
    axi_stream ch_4();
    axi_stream ch_5();
    axi_stream ch_6();

    axi_lite control_axi();
    AXI fcore();
    axi_lite dma_axi();
    axi_stream uscope();
    wire clock, reset, slow_clock, dma_done;


    Zynq_axis_wrapper #(
        .FCORE_PRESENT(0)
    ) TEST(        
        .Logic_Clock(clock),
        .IO_clock(slow_clock),
        .Reset(reset),
        .axi_out(control_axi),
        .dma_axi(dma_axi),
        .fcore_axi(fcore),
        .scope(uscope),
        .dma_done(dma_done)
    );


    localparam SCOPE_BASE = 32'h43C00000;
    localparam GPIO_BASE  = 32'h43C01000;

    axi_lite #(.INTERFACE_NAME("PWM")) scope_axi();
    axi_lite #(.INTERFACE_NAME("ALIGNER")) gpio_axi();


    axil_crossbar_interface #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(32),
        .NM(1),
        .NS(2),
        .SLAVE_ADDR('{SCOPE_BASE, GPIO_BASE}),
        .SLAVE_MASK('{2{32'h0f000}})
    ) axi_xbar (
        .clock(clock),
        .reset(reset),
        .slaves('{control_axi}),
        .masters('{scope_axi, gpio_axi})
    );


    wire ss, sclk;
    wire [5:0] miso;
    assign miso = {A_SDO_08, A_SDO_07, A_SDO_06, A_SDO_05, A_SDO_04, A_SDO_01};
    assign A_CONV_0508 = ss;
    assign A_CONV_0104 = ss;
    assign A_SCLK_0508 = sclk;
    assign A_SCLK_0104 = sclk;

    mc_scope_tl #(
        .BASE_ADDRESS(SCOPE_BASE)
    ) test(
        .clock(clock),
        .reset(reset),
        .enable(data_gen_en),
        .dma_done(dma_done),
        .dma_axi(dma_axi),
        .out(uscope),
        .MISO(miso),
        .SS(ss),
        .SCLK(sclk),
        .axi_in(scope_axi)
    );


    gpio #(
        .INPUT_WIDTH(0),
        .OUTPUT_WIDTH(1)
    ) setpoint_gpio(
        .clock(clock),
        .reset(reset),
        .gpio_o(data_gen_en),
        .axi_in(gpio_axi)
    );

endmodule