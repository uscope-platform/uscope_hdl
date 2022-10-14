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

`timescale 10ns / 1ns
`include "interfaces.svh"
import fcore_isa::*;

module fCore_exec #(
    OPCODE_WIDTH = 4, 
    DATA_WIDTH = 32, 
    REG_ADDR_WIDTH = 4, 
    RECIPROCAL_PRESENT=0,
    BITMANIP_IMPLEMENTED = 0,
    LOGIC_IMPLEMENTED = 0,
    FULL_COMPARE = 1
) (
    input wire clock,
    input wire reset,
    input wire [OPCODE_WIDTH-1:0] opcode,
    axi_stream.slave operand_a,
    axi_stream.slave operand_b,
    axi_stream.slave operand_c,
    axi_stream.slave operation,
    axi_stream.master result
);

    localparam  PIPELINE_LENGTH = 5+3*RECIPROCAL_PRESENT;


    
    reg [OPCODE_WIDTH-1:0] opcode_dly[PIPELINE_LENGTH:0];

    always@(posedge clock)begin

        opcode_dly[0][OPCODE_WIDTH-1:0] <= opcode;
        for(integer i =0 ; i<PIPELINE_LENGTH; i= i+1) begin
            opcode_dly[i+1][OPCODE_WIDTH-1:0] <= opcode_dly[i][OPCODE_WIDTH-1:0];
        end
    end



    fCore_FP_ALU #(
        .OPCODE_WIDTH(OPCODE_WIDTH),
        .REGISTER_ADDR_WIDTH(REG_ADDR_WIDTH),
        .PIPELINE_DEPTH(PIPELINE_LENGTH),
        .RECIPROCAL_PRESENT(RECIPROCAL_PRESENT),
        .BITMANIP_IMPLEMENTED(BITMANIP_IMPLEMENTED),
        .LOGIC_IMPLEMENTED(LOGIC_IMPLEMENTED),
        .FULL_COMPARE(FULL_COMPARE)
        )fp_alu(
        .clock(clock),
        .reset(reset),
        .result_select(opcode_dly[PIPELINE_LENGTH]),
        .operand_a(operand_a),
        .operand_b(operand_b),
        .operand_c(operand_c),
        .operation(operation),
        .result(result)
    );



    
endmodule
