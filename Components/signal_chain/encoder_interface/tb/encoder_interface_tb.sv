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
`include "axi_lite_BFM.svh"
`include "axis_BFM.svh"
`include "interfaces.svh"


module encoder_interface_tb();

    reg  clk, reset;
    reg a, b, z, a_blank;
    reg sample_angle, sample_speed;
    reg [15:0] enc_emu_ctr = 0;
    
    axi_lite control_axi();
    axi_stream angle();
    axi_stream speed();



    axi_lite_BFM axil_bfm;

    encoder_interface  UUT(
        .clock(clk),
        .reset(reset),
        .a(a & ~a_blank),
        .b(b),
        .z(z),
        .sample_angle(sample_angle),
        .sample_speed(sample_speed),
        .axi_in(control_axi),
        .angle(angle),
        .speed(speed)
    );


    event configuration_done;

    //clock generation
    initial clk = 0; 
    always #0.5 clk = ~clk; 

    initial begin
        a = 0;
        sample_speed = 0;
        sample_angle = 0;
        b = 0;
        a_blank = 0;
        z = 0;
        axil_bfm = new(control_axi, 1);
        reset <=1'h1;
        #1 reset <=1'h0;
        //TESTS
        #5.5 reset <=1'h1;

        #2 axil_bfm.write(reg_maps::encoder_if.angle_dest, 47); // slow 1 0
        #2 axil_bfm.write(reg_maps::encoder_if.speed_dest, 33); // slow 1 0
        #2 axil_bfm.write(reg_maps::encoder_if.max_count, 1202); // slow 1 0

        ->configuration_done;
    end


    
    always begin
     #14 a = 1;
     #14 a = 0;
    end

    initial begin
        #7;
        forever begin
            #14 b = 1;
            #14 b = 0;   
        end
    end

    initial begin
        #(28*200);
        forever begin
            z <= 1;
            #5;
            z <= 0;
            #(1202*7-5);
            
        end
    end

    initial begin
        #(28*420);
        forever begin
            #19234;
            a_blank <= 1;
            # 400;
            a_blank <= 0;
        end
    end


    initial begin

        @(configuration_done);
        forever begin 
            #50000;
            sample_speed = 1;
            sample_angle = 1;
            # 1;
            sample_speed = 0;
            sample_angle = 0;
        end
    end


endmodule