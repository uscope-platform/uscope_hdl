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
`include "interfaces.svh"

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

    reg [31:0] cu_read_registers [2:0];
    reg [31:0] cu_write_registers [2:0];
    reg tap_write;
    
    axil_simple_register_cu #(
        .N_READ_REGISTERS(3),
        .N_WRITE_REGISTERS(3),
        .N_TRIGGER_REGISTERS(1),
        .TRIGGER_REGISTERS_IDX('{2}),
        .ADDRESS_MASK('h0FF)
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(cu_read_registers),
        .output_registers(cu_write_registers),
        .trigger_out(tap_write),
        .axil(cfg_in)
    );

    assign cu_read_registers = cu_write_registers;

    wire [31:0] control;
    wire [15:0] tap_addr;
    wire [WORKING_WIDTH-1:0] tap_data;

    assign control = cu_write_registers[0];
    assign tap_data = cu_write_registers[1];
    assign tap_addr = cu_write_registers[2];

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
                .tap_data(tap_data),
                .tap_addr(tap_addr),
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
                .n_taps(control),
                .tap_data(tap_data),
                .tap_addr(tap_addr),
                .tap_write(tap_write),
                .data_in(data_in),
                .data_out(data_out)
            );
        end else begin
            $error("%m ** Illegal Parameter value ** FILTER_IMPLEMENTATION can be either SERIAL or PARALLEL");
        end   
        
    endgenerate
    




endmodule