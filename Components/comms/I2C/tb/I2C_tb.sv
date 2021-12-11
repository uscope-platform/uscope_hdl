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

module I2C_tb();
    
    logic clk, rst;

    Simplebus cfg_sb();
    
    simplebus_BFM BFM;

    reg start;
    
    reg response, slave_disable;

    wire i2c_scl, sda_in, sda_out;
    wire i2c_sda, scl_in, scl_out;
    wire i2c_scl_en, i2c_sda_en; 

    assign i2c_sda = i2c_sda_en ? sda_out : 1'b1; // put z instead of 1 when a slave is connected
    assign sda_in = i2c_sda;

    assign i2c_scl = i2c_scl_en & ~scl_out ? 0 : 1'b1; // put z instead of 1 when a slave is connected


    always@(*)begin
        if(i2c_scl_en)begin
        end else begin
        end
    end

    assign scl_in = i2c_scl;

    Simplebus s();
    Simplebus i2c_sb();
    
    defparam UUT.FIXED_PERIOD = "TRUE";
    I2c UUT(
        .clock(clk),
        .reset(rst),
        .i2c_scl_in(scl_in),
        .i2c_scl_out(scl_out),
        .i2c_sda_out_en(i2c_sda_en),
        .i2c_sda_in(sda_in),
        .i2c_sda_out(sda_out),
        .i2c_scl_out_en(i2c_scl_en),
        .sb(i2c_sb)
    );


    SimplebusInterconnect_M2_S1 xbar(
        .clock(clk),
        .master_1(cfg_sb),
        .master_2(s),
        .slave(i2c_sb)
    );

    si5351_config configurator(
        .clock(clk),
        .reset(rst),
        .start(start),
        .slave_address(8'h62),
        .sb(cfg_sb)

    );

    logic [31:0] readdata;
    
    //clock generation
    initial clk = 0; 
    always #1.25 clk = ~clk; 
    
    // reset generation
    initial begin
        BFM = new(s,1);
        start <= 0;
        rst <=1;
        slave_disable <=0;
        #3.5 rst<=0;
        #10.5 rst <=1;
        
        BFM.write(0+8'h10,32'h30);
        
        #5 BFM.read(0+8'h10,readdata);
        
        //BFM.write(0+8'h4,32'h100);

        #30 start <= 1;
        #1.5 start <= 0;
        #77950 slave_disable <= 1;
    end

    
/*
    initial begin
        response <= 1;
        #135.5;
        forever begin
            #369 response <= 0;
            #31 response <= 1;
            #400 response <= 0;
            #31 response <= 1;    
            #400 response <= 0;
            #31 response <= 1;  
            #269;
        end
        
    end
*/
    
endmodule