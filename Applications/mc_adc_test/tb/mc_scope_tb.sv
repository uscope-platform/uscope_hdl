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
`timescale 10 ns / 1 ns
`include "SimpleBus_BFM.svh"
`include "interfaces.svh"
`include "SPI_BFM.svh"
//import axi_vip_pkg::*;
//import VIP_axi_vip_0_0_pkg::*;

module mc_scope_tb();
    
    event start_spi_transfers;
    
    reg clk, rst, dma_done, enable;
    axi_stream uscope();
    axi_lite dma_axi();

    SPI_BFM spi_BFM_1;
    SPI_BFM spi_BFM_2;
    SPI_BFM spi_BFM_3;
    SPI_BFM spi_BFM_4;
    SPI_BFM spi_BFM_5;
    SPI_BFM spi_BFM_6;

    SPI_if adc_1();
    SPI_if adc_2();
    SPI_if adc_3();
    SPI_if adc_4();
    SPI_if adc_5();
    SPI_if adc_6();
    SPI_if resolver_spi();
    
    wire [5:0] miso;
    wire ss;
    wire sclk;

    assign adc_1.SCLK = sclk;
    assign adc_2.SCLK = sclk;
    assign adc_3.SCLK = sclk;
    assign adc_4.SCLK = sclk;
    assign adc_5.SCLK = sclk;
    assign adc_6.SCLK = sclk;

    assign adc_1.SS = ss;
    assign adc_2.SS = ss;
    assign adc_3.SS = ss;
    assign adc_4.SS = ss;
    assign adc_5.SS = ss;
    assign adc_6.SS = ss;
    
    assign miso[0] =  adc_1.MISO;
    assign miso[1] =  adc_2.MISO;
    assign miso[2] =  adc_3.MISO;
    assign miso[3] =  adc_4.MISO;
    assign miso[4] =  adc_5.MISO;
    assign miso[5] =  adc_6.MISO;

    Simplebus s();
    simplebus_BFM sb_BFM; 
    
    defparam UUT.BASE_ADDRESS = 32'h43C00100;
    mc_scope_tl UUT(
        .clock(clk),
        .reset(rst),
        .enable(enable),
        .dma_done(dma_done),
        .dma_axi(dma_axi),
        .MISO(miso),
        .SS(ss),
        .SCLK(sclk),
        .out(uscope),
        .sb(s)
    );

    //dma_vip_wrapper VIP( 
    //    .clock(clk),
    //    .reset(rst),
    //    .dma_done(dma_done),
    //    .axi(dma_axi),
    //    .stream(uscope)
    //);




    //VIP_axi_vip_0_0_slv_mem_t slv_agent;

    //clock generation
    initial clk = 0; 
    always #0.5 clk = ~clk; 
    // reset generation
    initial begin
        sb_BFM = new(s,1);
        //slv_agent = new("slave agent", mc_scope_tb.VIP.VIP_i.axi_vip_0.inst.IF);
        //slv_agent.start_slave();
        spi_BFM_1 = new(adc_1,1);
        spi_BFM_2 = new(adc_2,1);
        spi_BFM_3 = new(adc_3,1);
        spi_BFM_4 = new(adc_4,1);
        spi_BFM_5 = new(adc_5,1);
        spi_BFM_6 = new(adc_6,1);
        enable = 0;
        rst <=1;
        #3.5 rst<=0;
        #25 rst <=1;

        ->start_spi_transfers;
        #5;

        sb_BFM.write('h43c00304, 'h1b);
        sb_BFM.write('h43c00300, 'h101e2);
        #3 enable=1;
       

    end

    initial begin : adc_slave_1
        
        @(start_spi_transfers);
        forever begin
            @(posedge ss);
            spi_BFM_1.adc_Conversion(14'h1111);
        end
    end

    initial begin : adc_slave_2
        @(start_spi_transfers);
        forever begin
            @(posedge ss);
            spi_BFM_2.adc_Conversion(14'h1112);
        end
    end

    initial begin : adc_slave_3
        @(start_spi_transfers);
        forever begin
            @(posedge ss);
            spi_BFM_3.adc_Conversion(14'h1113);
        end
    end

    initial begin : adc_slave_4
        @(start_spi_transfers);
        forever begin
            @(posedge ss);
            spi_BFM_4.adc_Conversion(14'h1114);
        end
    end
    
    initial begin : adc_slave_5
        @(start_spi_transfers);
        forever begin
            @(posedge ss);
            spi_BFM_5.adc_Conversion(14'h1115);
        end
    end

    initial begin : adc_slave_6
        @(start_spi_transfers);
        forever begin
            @(posedge ss);
            spi_BFM_6.adc_Conversion(14'h1116);
        end
    end



endmodule