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

module single_stream_fault_detector #(
    parameter STARTING_DEST = 0
)(
    input wire clock,
    input wire reset,
    axi_stream.watcher  data_in,
    axi_lite.slave    axi_in,
    input wire clear_fault,
    output wire        fault
);

    wire fast_fault;
    wire slow_fault;

    typedef struct {
        reg [31:0] slow_threshold_low;
        reg [31:0] slow_threshold_high;
        reg [31:0] slow_trip_duration;
        reg [31:0] fast_threshold_low;
        reg [31:0] fast_threshold_high;
        reg [31:0] fault;
    } single_stream_fault_detector_registers;

    single_stream_fault_detector_registers read_registers, write_registers;

    axil_simple_register_cu #(
        .READ_TYPE(single_stream_fault_detector_registers),
        .WRITE_TYPE(single_stream_fault_detector_registers),
        .ADDRESS_MASK('hff)
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(read_registers),
        .output_registers(write_registers),
        .axil(axi_in)
    );

    always_comb begin
        read_registers = write_registers;
        read_registers.fault = {fast_fault, slow_fault};
    end


    assign fault = fast_fault | slow_fault;

    fault_detector_core #(
        .N_CHANNELS(1),
        .STARTING_DEST(STARTING_DEST)
    ) detector (
        .clock(clock),
        .reset(reset),
        .fast_threshold_low(write_registers.fast_threshold_low),
        .fast_threshold_high(write_registers.fast_threshold_high),
        .slow_threshold_low(write_registers.slow_threshold_low),
        .slow_threshold_high(write_registers.slow_threshold_high),
        .slow_trip_duration(write_registers.slow_trip_duration),
        .data_in(data_in),
        .clear_fault(clear_fault),
        .fast_fault(fast_fault),
        .slow_fault(slow_fault)
    );

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
            },
            {
                "name": "fault",
                "n_regs": ["1"],
                "description": "Fault status register",
                "direction": "RW",
                "fields":[
                    {
                        "name":"slow_fault",
                        "description": "Slow fault tripped",
                        "start_position": 0,
                        "n_fields":["1"],
                        "length": 1
                    }, 
                    {
                        "name": "fast_fault",
                        "description": "fast fault tripped",
                        "start_position": 1,
                        "n_fields":["1"],
                        "length": 1
                    }
                ]
            }
        ]
    }  
    **/
