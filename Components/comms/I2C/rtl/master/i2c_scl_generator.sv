// Copyright 2026 Filippo Savi
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

module i2c_scl_generator #(parameter COUNTER_WIDTH = 32)(
    input wire       clock,
    input wire       reset,
    input wire      enable,
    input wire [COUNTER_WIDTH-1:0] period,
    output reg       timebase,
    output reg       sampling_tb
);


    

    reg [COUNTER_WIDTH-1:0] enable_counter;
    reg [COUNTER_WIDTH-1:0] internal_period;

    wire [COUNTER_WIDTH-1:0] time_unit;
    assign time_unit = internal_period >> 2;

    always_ff @(posedge clock)begin
        if(~reset)begin
            enable_counter <=0;
            internal_period <= period;
        end else begin
            if(enable & internal_period != 0) begin
                if(enable_counter==internal_period-1) begin
                    enable_counter <= 0;
                end else begin
                    enable_counter <= enable_counter+1;
                end
            end else begin
                enable_counter <= 0;
                internal_period <= period;
            end
        end
    end
    
    always_ff @(posedge clock)begin
        if(~reset)begin
            timebase <=0;
            sampling_tb<= 0;
        end else begin
            if(enable & internal_period != 0) begin
                if(enable_counter>2*time_unit-1)begin
                    timebase <= 1;
                end else begin
                    timebase <= 0;
                end

                if(enable_counter>time_unit-1 && enable_counter<3*time_unit-1)begin
                    sampling_tb <= 1;
                end else begin
                    sampling_tb <= 0;
                end
            end else begin
                timebase <= 0;
                sampling_tb <= 0;
            end
        end
    end

endmodule