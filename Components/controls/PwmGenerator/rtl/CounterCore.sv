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

module counter_core #(
    parameter COUNTER_WIDTH = 16
)(
    input wire clock,
    input wire reset,
    input wire timebase,
    input wire fast_count,
    input wire enable,
    input wire direction,
    input wire inhibit_load,
    input wire  [COUNTER_WIDTH-1:0] shift,  
    input wire [COUNTER_WIDTH-1:0] reload_value,
    output reg [COUNTER_WIDTH-1:0] count_out
);

    reg [COUNTER_WIDTH-1:0] count = {COUNTER_WIDTH{1'b0}};
    reg [COUNTER_WIDTH-1:0] fast_counter = {COUNTER_WIDTH{1'b0}};
    
    reg [COUNTER_WIDTH-1:0] unregistered_count_out;

    // output register to improve timing
    always @(posedge clock) begin 
        count_out <= unregistered_count_out;
    end
    
    reg [COUNTER_WIDTH:0] raw_shifted_counter;
    reg [COUNTER_WIDTH:0] fast_raw_shifted_counter;

    always_comb begin
        if(fast_count)begin
            if(fast_raw_shifted_counter>=reload_value)begin
                unregistered_count_out <= fast_raw_shifted_counter-reload_value; 
            end else begin
                unregistered_count_out <= fast_raw_shifted_counter;
            end
        end else begin
            if(raw_shifted_counter>=reload_value)begin
                unregistered_count_out <= raw_shifted_counter-reload_value; 
            end else begin
                unregistered_count_out <= raw_shifted_counter;
            end
        end
    end
    
    // DIVIDED COUNTER
    always @(posedge clock) begin 
        raw_shifted_counter <= count+shift;
        fast_raw_shifted_counter <= fast_counter+shift;
        if (~reset)
            count <= {COUNTER_WIDTH{1'b0}};
        else if(enable) begin
            if(count==reload_value & inhibit_load)
                count <= 0;
            if(timebase)begin
                if (~direction)
                    count <= count + 1'b1;
                else
                    count <= count - 1'b1;
            end 
        end else begin
            count <= 0;
        end
    end
    

    // FAST COUNTER
    always @(posedge clock) begin 
        if (~reset)
            fast_counter <= {COUNTER_WIDTH{1'b0}};
        else if(enable) begin
            if (~direction)
                fast_counter <= fast_counter + 1'b1;
            else
                fast_counter <= fast_counter - 1'b1;
            if(fast_counter==reload_value & inhibit_load)
                fast_counter <= 0;
        end else begin
            fast_counter <= 0;
        end
    end

endmodule