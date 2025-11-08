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

module fault_detector_core #(
    parameter N_CHANNELS = 4,
    parameter STARTING_DEST = 0
)(
    input wire clock,
    input wire reset,
    input wire signed [31:0] fast_threshold_low,
    input wire signed [31:0] fast_threshold_high,
    input wire signed [31:0] slow_threshold_low,
    input wire signed [31:0] slow_threshold_high,
    input wire [7:0] slow_trip_duration,
    axi_stream.watcher  data_in,
    input wire clear_fault,
    output reg [31:0] fast_fault_origin,
    output reg [31:0] slow_fault_origin,
    output wire fast_fault,
    output wire slow_fault
);

    assign fast_fault = |fast_fault_origin;
    assign slow_fault = |slow_fault_origin;

    wire signed[data_in.DATA_WIDTH-1:0] signed_data = $signed(data_in.data);
    wire [7:0] current_address = data_in.dest - STARTING_DEST;

    wire fast_trip =  $signed(signed_data) < $signed(fast_threshold_low) || $signed(signed_data) > $signed(fast_threshold_high);
    wire slow_trip = ($signed(signed_data) < $signed(slow_threshold_low) || $signed(signed_data) > $signed(slow_threshold_high)) & ~fast_trip;

    reg [7:0] slow_trip_counter [N_CHANNELS-1:0] = '{N_CHANNELS{8'h0}};


    always @(posedge clock) begin
        if(~reset)begin
            fast_fault_origin <= 0;
            slow_fault_origin <= 0;
        end else begin
            if(slow_fault_origin || fast_fault_origin)begin
                if(clear_fault)begin
                    slow_fault_origin <= 0;
                    fast_fault_origin <= 0;
                    slow_trip_counter <= '{N_CHANNELS{8'h0}};
                end
            end else begin
                if(data_in.valid) begin
                    if(fast_trip) begin
                        fast_fault_origin[current_address] <= 1;
                    end
                    if(slow_trip) begin
                        slow_trip_counter[current_address] <= slow_trip_counter[current_address] + 1;
                    end
                    if(slow_trip_counter[current_address] != 0 & !slow_trip)begin
                        slow_trip_counter[current_address] <= 0;
                    end
                end
                    if(slow_trip_counter[current_address]==slow_trip_duration && slow_trip_duration != 0) begin
                        slow_fault_origin[current_address] <= 1;
                    end
            end
        end
    end



endmodule



 /**
       {
        "name": "stream_fault_detector",
        "type": "parametric_peripheral",
        "registers":[
            {
                "name": "slow_tresh_low",
                "n_regs": ["1"],
                "description": "Slow fault lower treshold",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "slow_tresh_high",
                "n_regs": ["1"],
                "description": "Slow fault higher treshold",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "slow_trip_duration",
                "n_regs": ["1"],
                "description": "Number of cycles after which a slow fault is triggered",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "fast_tresh_low",
                "n_regs": ["1"],
                "description": "Fast fault lower treshold",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "fast_tresh_high",
                "n_regs": ["1"],
                "description": "Fast fault higher treshold",
                "direction": "RW",
                "fields":[]
            }
        ]
    }  
    **/
