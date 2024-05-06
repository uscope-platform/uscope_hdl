// Copyright 2024 Filippo Savi
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
`include "interfaces.svh"
`include "axis_BFM.svh"
`include "axi_lite_BFM.svh"
`include "SPI_BFM.svh"

module spi_adc_interface_tb();
    
    logic clk, rst, ss, sclk, sample;
    reg [1:0] miso;
    event test_start;

    axi_lite control();
    axi_stream data_out();


    SPI_if spi_if_1();
    assign spi_if_1.SS = ss;
    assign spi_if_1.SCLK = sclk;
    assign miso[0] = spi_if_1.MISO;

    SPI_if spi_if_2();
    assign spi_if_2.SS = ss;
    assign spi_if_2.SCLK = sclk;
    assign miso[1] = spi_if_2.MISO;

    spi_adc_interface #(
        .N_CHANNELS(2),
        .DATAPATH_WIDTH(12),
        .DESTINATIONS('{7,5})
    )UUT(
        .clock(clk),
        .reset(rst),
        .MISO(miso),
        .SCLK(sclk),
        .SS(ss),
        .sample(sample),
        .axi_in(control),
        .data_out(data_out)
    );

    axi_lite_BFM axil_bfm;
    SPI_BFM spi_bfm_1;
    SPI_BFM spi_bfm_2;

    initial begin
        axil_bfm = new(control, 1);
        spi_bfm_1 = new(spi_if_1,1);
        spi_bfm_2 = new(spi_if_2,1);
    end

    //clock generation
    initial clk = 1; 
    always #0.5 clk = ~clk; 

    
    // reset generation
    initial begin
        rst <=1;
        #3 rst<=0;
        #5 rst <=1;
        #15;

        #10 axil_bfm.write('h0, 'h1e184);
        ->test_start;
    end


    logic [11:0] slave_data_s1 = 0;
    logic [11:0] slave_data_e1 = 0;
    logic [11:0] slave_data_s2 = 0;
    logic [11:0] slave_data_e2 = 0;
    logic [11:0] master_data_r =0;

    initial begin
        @(test_start);

        forever begin
            #50 sample <= 1;
            #1 sample <= 0;
        end
    end

    initial begin
        @(test_start);

        forever begin
            slave_data_s1 = $urandom;
            spi_bfm_1.transfer(slave_data_s1, 12,master_data_r);
            slave_data_e1 = slave_data_s1;
        end
    end

        initial begin
        @(test_start);
        forever begin
            slave_data_s2 = $urandom;
            spi_bfm_2.transfer(slave_data_s2, 12,master_data_r);
            slave_data_e2 = slave_data_s2;
        end
    end

endmodule