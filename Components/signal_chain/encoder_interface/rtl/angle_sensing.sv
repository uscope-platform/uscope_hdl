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

module angle_sensing (
    input wire clock,
    input wire reset,
    input wire [31:0] output_destination,
    input wire [23:0] max_count,
    input wire a,
    input wire b,
    input wire z,
    input wire sample,
    output wire [31:0] angle_out,
    axi_stream.master angle
);

    reg[23:0] angle_counter = 0;
    reg[23:0] zero_value = 0;

    reg a_prev, b_prev, z_prev;

    wire step = a ^ a_prev ^ b ^ b_prev;
    wire direction = a ^ b_prev;
    
    reg zeroing_enabled;
    reg initial_zero_tracking;

    assign angle_out = angle_counter;
    
    always_ff @(posedge clock) begin
        a_prev <= a;
        b_prev <= b;

        if(angle_counter == max_count)begin
            angle_counter <= 0;
        end 
        
        if(step) begin
            if(direction) 
                angle_counter<=angle_counter+1; 
            else 
                angle_counter<=angle_counter-1;
        end
        z_prev <= z;

        if(~z_prev & z)begin
            if(initial_zero_tracking & zeroing_enabled)begin
                angle_counter <= zero_value;
            end else if(initial_zero_tracking) begin
                zero_value <= angle_counter;
                zeroing_enabled <= 1;
            end else begin
                initial_zero_tracking <= 1;
            end
        end
        
    end


    always_ff @(posedge clock) begin

        angle.valid <= 0;
        if(sample)begin
            angle.data <= angle_counter;
            angle.dest <= output_destination;
            angle.valid <= 1;
        end
    end

endmodule
