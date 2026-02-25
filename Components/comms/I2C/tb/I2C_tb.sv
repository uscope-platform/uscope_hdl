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
`include "axis_BFM.svh"

module I2C_tb();
    
    logic clk, rst;

    reg start;
    
    reg slave_disable;

    wire i2c_scl, sda_in, sda_out;
    wire i2c_sda, scl_in, scl_out;
    wire i2c_scl_en, i2c_sda_en; 

    assign i2c_sda = i2c_sda_en ? sda_out : 1'b1; // put z instead of 1 when a slave is connected
    assign sda_in = i2c_sda;

    assign i2c_scl = i2c_scl_en & ~scl_out ? 0 : 1'b1; // put z instead of 1 when a slave is connected

    assign scl_in = i2c_scl;

    axi_stream write();


    si5351_config configurator(
        .clock(clk),
        .reset(rst),
        .start(start),
        .slave_address(8'h62),
        .config_out(write)
    );


    I2c UUT(
        .clock(clk),
        .reset(rst),
        .i2c_scl_in(scl_in),
        .i2c_scl_out(scl_out),
        .i2c_sda_out_en(i2c_sda_en),
        .i2c_sda_in(sda_in),
        .i2c_sda_out(sda_out),
        .i2c_scl_out_en(i2c_scl_en),
        .message_if(write)
    );



    logic [31:0] readdata;
    
    //clock generation
    initial clk = 0; 
    always #0.5 clk = ~clk; 
    
    // reset generation
    initial begin
        readdata = 0;
        start = 0;
        rst =1;
        slave_disable =0;
        #10 rst = 0;
        #10.5 rst = 1;

        #30 start <= 1;
        #1.5 start <= 0;
        #77950 slave_disable <= 1;
    end


    
endmodule