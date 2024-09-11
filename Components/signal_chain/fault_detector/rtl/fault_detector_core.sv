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

module fault_detector_core #(
    parameter N_CHANNELS = 4,
    parameter STARTING_DEST = 0
)(
    input wire clock,
    input wire reset,
    input wire signed [31:0] fast_thresholds [1:0],
    input wire signed [31:0] slow_thresholds [1:0],
    input wire [7:0] slow_trip_duration,
    axi_stream.watcher  data_in,
    input wire clear_fault,
    output reg fast_fault,
    output reg slow_fault
);


    wire signed[data_in.DATA_WIDTH-1:0] signed_data = $signed(data_in.data);
    wire [7:0] current_address = data_in.dest - STARTING_DEST;

    wire fast_trip =  $signed(signed_data) < $signed(fast_thresholds[0]) || $signed(signed_data) > $signed(fast_thresholds[1]);
    wire slow_trip = ($signed(signed_data) < $signed(slow_thresholds[0]) || $signed(signed_data) > $signed(slow_thresholds[1])) & ~fast_trip;

    reg [7:0] slow_trip_counter [N_CHANNELS-1:0] = '{N_CHANNELS{8'h0}};


    always @(posedge clock) begin
        if(~reset)begin
            fast_fault <= 0;
            slow_fault <= 0;
        end else begin
            if(slow_fault || fast_fault)begin
                if(clear_fault)begin
                    slow_fault <= 0;
                    fast_fault <= 0;
                    slow_trip_counter <= '{N_CHANNELS{8'h0}};
                end
            end else begin
                if(data_in.valid) begin
                    if(fast_trip) begin
                        fast_fault <= 1;
                    end
                    if(slow_trip) begin
                        slow_trip_counter[current_address] <= slow_trip_counter[current_address] + 1;
                    end
                    if(slow_trip_counter[current_address] != 0 & !slow_trip)begin
                        slow_trip_counter[current_address] <= 0;
                    end
                end
                    if(slow_trip_counter[current_address]==slow_trip_duration && slow_trip_duration != 0) begin
                        slow_fault <= 1;
                    end
            end
        end
    end



endmodule


 /**
       {
        "name": "stream_fault_detector",
        "type": "peripheral",
        "registers":[
            {
                "name": "slow_tresh_low",
                "offset": "0x0",
                "description": "Slow fault lower treshold",
                "direction": "RW"
            },
            {
                "name": "slow_tresh_high",
                "offset": "0x4",
                "description": "Slow fault higher treshold",
                "direction": "RW"
            },
            {
                "name": "slow_trip_duration",
                "offset": "0x8",
                "description": "Number of cycles after which a slow fault is triggered",
                "direction": "RW"
            },
            {
                "name": "fast_tresh_low",
                "offset": "0xC",
                "description": "Fast fault lower treshold",
                "direction": "RW"
            },
            {
                "name": "fast_tresh_high",
                "offset": "0x10",
                "description": "Fast fault higher treshold",
                "direction": "RW"
            }
        ]
    }  
    **/
