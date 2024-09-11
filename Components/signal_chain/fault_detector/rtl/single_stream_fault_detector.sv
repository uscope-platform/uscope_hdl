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

module single_stream_fault_detector #(
    parameter N_CHANNELS = 4,
    parameter STARTING_DEST = 0
)(
    input wire clock,
    input wire reset,
    axi_stream.watcher  data_in,
    axi_lite.slave    axi_in,
    input wire clear_fault,
    output wire        fault
);

    reg [31:0] cu_write_registers [5:0];
    reg [31:0] cu_read_registers  [5:0];


    axil_simple_register_cu #(
        .N_READ_REGISTERS(6),
        .N_WRITE_REGISTERS(6),
        .REGISTERS_WIDTH(32),
        .ADDRESS_MASK('hff)
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(cu_read_registers),
        .output_registers(cu_write_registers),
        .axil(axi_in)
    );


    wire fast_fault, slow_fault;

    assign fault = fast_fault | slow_fault;

    wire signed [31:0] fast_thresholds [1:0];
    wire signed [31:0] slow_thresholds [1:0];
    wire [7:0] slow_trip_duration;

    assign slow_thresholds[0] = cu_write_registers[0][31:0];
    assign slow_thresholds[1] = cu_write_registers[1][31:0];
    assign slow_trip_duration = cu_write_registers[2][7:0];
    assign fast_thresholds[0] = cu_write_registers[3][31:0];
    assign fast_thresholds[1] = cu_write_registers[4][31:0];

    assign cu_read_registers[4:0] = cu_write_registers[4:0];
    assign cu_read_registers[5] = {fast_fault, slow_fault};


    fault_detector_core #(
        .N_CHANNELS(N_CHANNELS),
        .STARTING_DEST(STARTING_DEST)
    ) detector (
        .clock(clock),
        .reset(reset),
        .fast_thresholds(fast_thresholds),
        .slow_thresholds(slow_thresholds),
        .slow_trip_duration(slow_trip_duration),
        .data_in(data_in),
        .clear_fault(clear_fault),
        .fast_fault(fast_fault),
        .slow_fault(slow_fault)
    );

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
