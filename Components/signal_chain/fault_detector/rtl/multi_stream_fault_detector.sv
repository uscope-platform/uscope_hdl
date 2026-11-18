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

module multi_stream_fault_detector #(
    parameter N_STREAMS = 2,
    parameter reg[31:0] N_CHANNELS [N_STREAMS-1:0] = '{default:4},
    parameter reg[31:0] STARTING_DEST [N_STREAMS-1:0] = '{default:0}
)(
    input wire clock,
    input wire reset,
    axi_stream.watcher  stream [N_STREAMS],
    axi_lite.slave    axi_in,
    input wire clear_fault,
    output wire fault
);

    wire [31:0] fast_fault [N_STREAMS-1:0];
    wire [31:0] slow_fault [N_STREAMS-1:0];

    typedef struct {
        reg [31:0] slow_thresholds_low[N_STREAMS];
        reg [31:0] slow_thresholds_high[N_STREAMS];
        reg [31:0] slow_trip_duration[N_STREAMS];
        reg [31:0] fast_thresholds_low[N_STREAMS];
        reg [31:0] fast_thresholds_high[N_STREAMS];
            
        reg [31:0] fast_fault [N_STREAMS];
        reg [31:0] slow_fault [N_STREAMS];

    } multi_stream_fault_detector_registers;

    multi_stream_fault_detector_registers read_registers, write_registers;

    axil_simple_register_cu #(
        .READ_TYPE(multi_stream_fault_detector_registers),
        .WRITE_TYPE(multi_stream_fault_detector_registers),
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
        read_registers.fast_fault = fast_fault;
        read_registers.slow_fault = slow_fault;
    end


    reg [N_STREAMS-1:0] collated_fast_fault;
    reg [N_STREAMS-1:0] collated_slow_fault;

    assign fault = |collated_fast_fault | |collated_slow_fault;

    genvar  j;

    generate

        for (j = 0; j<N_STREAMS; j++) begin

            fault_detector_core #(
                .N_CHANNELS(N_CHANNELS[j]),
                .STARTING_DEST(STARTING_DEST[j])
            ) detector (
                .clock(clock),
                .reset(reset),
                .fast_threshold_low(write_registers.fast_thresholds_low[j]),
                .fast_threshold_high(write_registers.fast_thresholds_high[j]),
                .slow_threshold_low(write_registers.slow_thresholds_low[j]),
                .slow_threshold_high(write_registers.slow_thresholds_high[j]),
                .slow_trip_duration(write_registers.slow_trip_duration[j]),
                .data_in(stream[j]),
                .clear_fault(clear_fault),
                .fast_fault(collated_fast_fault[j]),
                .slow_fault(collated_slow_fault[j]),
                .fast_fault_origin(fast_fault[j]),
                .slow_fault_origin(slow_fault[j])
            );

        end


    endgenerate



endmodule


    /**
       {
        "name": "multi_stream_fault_detector",
        "type": "parametric_peripheral",
        "registers":[
            {
                "name": "slow_treshold_low_$",
                "n_regs": ["N_STREAMS"],
                "description": "slow fault treshold low for stream $",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "slow_treshold_high_$",
                "n_regs": ["N_STREAMS"],
                "description": "slow fault treshold high for stream $",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "slow_trip_duration_$",
                "n_regs": ["N_STREAMS"],
                "description": "slow fault minimum duration for stream $",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "fast_treshold_low_$",
                "n_regs": ["N_STREAMS"],
                "description": "fast fault treshold low for stream $",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "fast_treshold_high_$",
                "n_regs": ["N_STREAMS"],
                "description": "fast fault treshold high for stream $",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "fast_fault_$",
                "n_regs": ["N_STREAMS"],
                "description": "fast fault status for stream $",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "slow_fault_$",
                "n_regs": ["N_STREAMS"],
                "description": "slow fault status for stream $",
                "direction": "RW",
                "fields":[]
            }
        ]
       }
    **/