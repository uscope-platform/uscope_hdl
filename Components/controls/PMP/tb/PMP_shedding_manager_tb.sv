

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
`include "interfaces.svh"

module PMP_shedding_manager_tb();
    reg clk, reset;

    reg [3:0] phases = 0;
    reg[15:0] period = 1666;
    reg[15:0] duty_in [11:0]= '{default:0};
    wire [15:0] duty_out [11:0];


    PMP_buck_shedding_manager #(
         .N_PHASES(12)
    ) ff_calculator (
        .clock(clk),
        .reset(reset),
        .n_phases(phases),
        .period(period),
        .duty_in(duty_in),
        .duty_out(duty_out)
    );
    
    event setup_done;
    initial clk = 0; 
    always #0.5 clk = ~clk; 

    reg phase_enable_done = 0;
    

    initial begin
        //Initial status
        reset <=1'h1;
        duty_in[0] <= 288;
        #1 reset <=1'h0;
        //TESTS
        #5.5 reset <=1'h1;
        #20.5;
        forever begin
            if(!phase_enable_done)begin
                phases <= phases + 1;
            end
            if(phases == 11) begin
                phase_enable_done <= 1;
                #2000;
                ->setup_done;
            end
            #50;
        end
    end

    reg sweep_done = 0;

    reg [15:0] sweep_counter = -1666;
    initial begin
        @(setup_done);
        forever begin
            if(sweep_counter==(1667+288))begin
                sweep_done<= 1;
            end
            if(~sweep_done)begin
                sweep_counter++;
                duty_in[1] <= sweep_counter;
                duty_in[2] <= sweep_counter;
                duty_in[3] <= sweep_counter;
                duty_in[4] <= sweep_counter;
                duty_in[5] <= sweep_counter;
                duty_in[6] <= sweep_counter;
                duty_in[7] <= sweep_counter;
                duty_in[8] <= sweep_counter;
                duty_in[9] <= sweep_counter;
                duty_in[10] <= sweep_counter;
                duty_in[11] <= sweep_counter;
            end
            #10;
        end
    end


endmodule