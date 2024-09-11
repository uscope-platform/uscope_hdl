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
    
    localparam N_REGISTERS = N_STREAMS*7;
    reg [31:0] cu_write_registers [N_REGISTERS-1:0];
    reg [31:0] cu_read_registers  [N_REGISTERS-1:0];


    axil_simple_register_cu #(
        .N_READ_REGISTERS(N_REGISTERS),
        .N_WRITE_REGISTERS(N_REGISTERS),
        .REGISTERS_WIDTH(32),
        .ADDRESS_MASK('hff)
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(cu_read_registers),
        .output_registers(cu_write_registers),
        .axil(axi_in)
    );


    wire [31:0] fast_fault [N_STREAMS-1:0];
    wire [31:0] slow_fault [N_STREAMS-1:0];

    reg [N_STREAMS-1:0] collated_fast_fault;
    reg [N_STREAMS-1:0] collated_slow_fault;

    assign fault = |collated_fast_fault | |collated_slow_fault;

    wire signed [31:0] fast_thresholds_low [N_STREAMS-1:0];
    wire signed [31:0] fast_thresholds_high [N_STREAMS-1:0];
    wire signed [31:0] slow_thresholds_low [N_STREAMS-1:0];
    wire signed [31:0] slow_thresholds_high [N_STREAMS-1:0];

    wire [7:0] slow_trip_duration [N_STREAMS-1:0];


    assign cu_read_registers[N_REGISTERS-3:0] = cu_write_registers[N_REGISTERS-3:0];


    genvar  i, j;

    generate


        for (i = 0; i<N_STREAMS; i++) begin
            
            assign slow_thresholds_low[i] = cu_write_registers[2*i][31:0];
            assign slow_thresholds_high[i] = cu_write_registers[2*i+1][31:0];

            assign slow_trip_duration[i] = cu_write_registers[N_STREAMS*2+i][7:0];

            assign fast_thresholds_low[i] = cu_write_registers[N_STREAMS*3+2*i][31:0];
            assign fast_thresholds_high[i] = cu_write_registers[N_STREAMS*3+2*i+1][31:0];
                    
            assign cu_read_registers[N_STREAMS*5+2*i]   = fast_fault[i];
            assign cu_read_registers[N_STREAMS*5+2*i+1] = slow_fault[i];

        end

        for (j = 0; j<N_STREAMS; j++) begin
            
            fault_detector_core #(
                .N_CHANNELS(N_CHANNELS[j]),
                .STARTING_DEST(STARTING_DEST[j])
            ) detector (
                .clock(clock),
                .reset(reset),
                .fast_threshold_low(fast_thresholds_low[j]),
                .fast_threshold_high(fast_thresholds_high[j]),
                .slow_threshold_low(slow_thresholds_low[j]),
                .slow_threshold_high(slow_thresholds_high[j]),
                .slow_trip_duration(slow_trip_duration[j]),
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
