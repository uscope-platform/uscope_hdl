// Copyright 2023 Filippo Savi
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

module fir_filter #(
    parameter DATA_PATH_WIDTH = 16,
    TAP_WIDTH = 16,
    WORKING_WIDTH = DATA_PATH_WIDTH > TAP_WIDTH ? DATA_PATH_WIDTH : TAP_WIDTH,
    FILTER_IMPLEMENTATION = "SERIAL",
    MAX_N_TAPS=8,
    parameter [WORKING_WIDTH-1:0] TAPS_IV [MAX_N_TAPS:0] = '{MAX_N_TAPS+1{0}}
)(
    input wire clock,
    input wire reset,
    axi_lite.slave cfg_in,
    axi_stream.slave data_in,
    axi_stream.master data_out
);

    typedef struct {
        reg [31:0] control;
        reg [31:0] tap_data;
        reg [31:0] tap_addr;
    } fir_filter_registers;

    fir_filter_registers registers;
    wire tap_write;

    axil_simple_register_cu #(
        .READ_TYPE(fir_filter_registers),
        .WRITE_TYPE(fir_filter_registers),
        .REGISTERS_WIDTH(32),
        .TRIGGER_MASK('{tap_addr: 1, default: 0}),
        .ADDRESS_MASK('hff)
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(registers),
        .output_registers(registers),
        .trigger_out(tap_write),
        .axil(cfg_in)
    );



    generate
        if(FILTER_IMPLEMENTATION =="PARALLEL")begin
            fir_filter_parallel #(
                .DATA_PATH_WIDTH(DATA_PATH_WIDTH),
                .TAP_WIDTH(TAP_WIDTH),
                .PARALLEL_ORDER(MAX_N_TAPS),
                .TAPS_IV(TAPS_IV)
            )filter_core(
                .clock(clock),
                .reset(reset),
                .tap_data(registers.tap_data),
                .tap_addr(registers.tap_addr),
                .tap_write(tap_write),
                .data_in(data_in),
                .data_out(data_out)
            );
        end else if(FILTER_IMPLEMENTATION == "SERIAL")begin
            fir_filter_serial #(
                .DATA_PATH_WIDTH(DATA_PATH_WIDTH),
                .TAP_WIDTH(TAP_WIDTH),
                .MAX_N_TAPS(MAX_N_TAPS),
                .TAPS_IV(TAPS_IV)
            )filter_core (
                .clock(clock),
                .reset(reset),
                .n_taps(registers.control),
                .tap_data(registers.tap_data),
                .tap_addr(registers.tap_addr),
                .tap_write(tap_write),
                .data_in(data_in),
                .data_out(data_out)
            );
        end else begin
            $error("%m ** Illegal Parameter value ** FILTER_IMPLEMENTATION can be either SERIAL or PARALLEL");
        end   
        
    endgenerate




 /**
    {
        "name": "fir_filter",
        "type": "parametric_peripheral",
        "registers":[
            {
                "name": "control",
                "n_regs": ["1"],
                "description": "Fir filter control register",
                "direction": "RW",
                "fields":[
                    {
                        "name":"n_taps",
                        "description": "Number of active FIR filter taps",
                        "start_position": 0,
                        "n_fields":["1"],
                        "length": 8
                    }
                ]
            },
            {
                "name": "tap_data",
                "n_regs": ["1"],
                "description": "Fir Filter tap data value",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "tap_addr",
                "n_regs": ["1"],
                "description": "Fir Filter tap address value (writing it triggers the tap memory write)",
                "direction": "RW",
                "fields":[]
            }
        ]
    }
 **/
    




endmodule