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
`include "interfaces.svh"

module TimebaseGenerator (
    input wire       clock,
    input wire       reset,
    input wire       enable,
    input wire       fast_count,
    input wire       counter_status,
    input wire [2:0] dividerSetting,
    output reg       timebaseOut
);
    reg [5:0] timebases;
    reg count2;
    reg [1:0] count4;
    reg [2:0] count8;
    reg [3:0] count16;
    reg [4:0] count32;
    
    reg selected_timebase;
    reg [2:0] shadow_dividerSetting;
    

    always_comb begin
        if(fast_count)begin
            timebaseOut <= clock;
        end else begin
            timebaseOut <= selected_timebase;
        end
    end


    always@(posedge clock) begin
        if(~counter_status)begin
            shadow_dividerSetting <= dividerSetting;
        end

        timebases[0] <= 0;
        if(~enable)begin
            selected_timebase <=0;
        end else begin
            selected_timebase <= timebases[shadow_dividerSetting];
        end
    end

    always @(posedge clock) begin
        if(~reset) begin
            // Clock/2 generation
            //update counters
            count2 <= 0;
            count4 <= 0;
            count8 <= 0;
            count16 <= 0;
            count32 <= 0;
        end else begin
            //update counters
            count2 <= count2 + 1'b1;
            count4 <= count4 + 1'b1;
            count8 <= count8 + 1'b1;
            count16 <= count16 + 1'b1;
            count32 <= count32 + 1'b1;
        end

    end

    always@(posedge clock) begin
        
        if (count2==1) begin
            timebases[1]<=1'b1;
        end else begin
            timebases[1]<=1'b0;
        end
        if (count4==1) begin
            timebases[2]<=1'b1;
        end else begin
            timebases[2]<=1'b0;
        end
        if (count8==1) begin
            timebases[3]<=1'b1;
        end else begin
            timebases[3]<=1'b0;
        end
        // Clock/4 generation
        if (count16==1) begin
            timebases[4]<=1'b1;
        end else begin
            timebases[4]<=1'b0;
        end
        // Clock/8 generation
        if (count32==1) begin
            timebases[5]<=1'b1;
        end else begin
            timebases[5]<=1'b0;
        end
    end

endmodule