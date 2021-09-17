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

    Simplebus s();
    Simplebus s1();
    Simplebus s2();
    APB apb();
    AXI fcore();
    axi_lite dma_axi();
    axi_stream uscope();
    wire clock, reset, slow_clock, dma_done;
    
    Zynq_axis_wrapper PS(
        .APB(apb),
        .Reset(reset),
        .Logic_Clock(clock),
        .IO_clock(slow_clock),
        .dma_axi(dma_axi),
        .fcore_axi(fcore),
        .scope(uscope),
        .dma_done(dma_done)
    );

    APB_to_Simplebus bridge(
        .PCLK(clock),
        .PRESETn(reset),
        .apb(apb),
        .spb(s)
    );

    defparam xbar.SLAVE_1_LOW = 32'h43C00000;
    defparam xbar.SLAVE_1_HIGH = 32'h43C000fc;
    defparam xbar.SLAVE_2_LOW =  32'h43C000fc;
    defparam xbar.SLAVE_2_HIGH =  32'h43C00700;

    SimplebusInterconnect_M1_S2 xbar (
        .clock(clock),
        .master(s),
        .slave_1(s1),
        .slave_2(s2) 
    );



    wire ss, sclk;
    wire [5:0] miso;
    assign miso = {A_SDO_08, A_SDO_07, A_SDO_06, A_SDO_05, A_SDO_04, A_SDO_01};
    assign A_CONV_0508 = ss;
    assign A_CONV_0104 = ss;
    assign A_SCLK_0508 = sclk;
    assign A_SCLK_0104 = sclk;

    defparam test.BASE_ADDRESS = 32'h43C00100;
    mc_scope_tl test(
        .clock(clock),
        .reset(reset),
        .enable(data_gen_en),
        .dma_done(dma_done),
        .dma_axi(dma_axi),
        .out(uscope),
        .MISO(miso),
        .SS(ss),
        .SCLK(sclk),
        .sb(s2)
    );



    defparam setpoint_gpio.BASE_ADDRESS = 'h43c00000;
    defparam setpoint_gpio.INPUT_WIDTH = 0;
    defparam setpoint_gpio.OUTPUT_WIDTH = 1;
    gpio setpoint_gpio(
        .clock(clock),
        .reset(reset),
        .gpio_o(data_gen_en),
        .sb(s1)
    );

endmodule