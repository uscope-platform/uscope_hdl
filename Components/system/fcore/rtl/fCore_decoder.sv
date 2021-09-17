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
`include "fCore_ISA.svh"

module fCore_decoder #(parameter INSTRUCTION_WIDTH = 16,MAX_CHANNELS = 255, DATAPATH_WIDTH = 16, PC_WIDTH = 12, OPCODE_WIDTH = 4, REG_ADDR_WIDTH=4, IMMEDIATE_WIDTH=12, CHANNEL_ADDR_WIDTH = 8)(
    input wire clock,
    input wire reset,
    input wire enable,
    input wire [$clog2(MAX_CHANNELS)-1:0] n_channels,
    input wire [INSTRUCTION_WIDTH-1:0] instruction,
    input wire [INSTRUCTION_WIDTH-1:0] load_data,
    input wire [CHANNEL_ADDR_WIDTH-1:0] channel_address,
    output reg [OPCODE_WIDTH-1:0] exec_opcode,
    output reg core_stop,
    axi_stream.master operand_a_if,
    axi_stream.master operand_b_if,
    axi_stream.master operation_if
    );

    enum { 
        NOP = 0,
        ADD = 1,
        SUB = 2,
        MUL = 3,
        ITF = 4,
        FTI = 5,
        LDC = 6,
        LDR = 7,
        BGT = 8,
        BLE = 9,
        BEQ = 10,
        BNE = 11,
        STOP = 12,
        AND = 13,
        OR = 14,
        NOT = 15,
        SATP = 16,
        SATN = 17,
        REC = 18
    }ISA;


    wire [OPCODE_WIDTH-1:0] opcode;
    assign opcode = instruction[OPCODE_WIDTH-1:0];

    wire [REG_ADDR_WIDTH-1:0] operand_a;
    assign operand_a = instruction[OPCODE_WIDTH+REG_ADDR_WIDTH-1:OPCODE_WIDTH];

    wire [REG_ADDR_WIDTH-1:0] operand_b;
    assign operand_b = instruction[OPCODE_WIDTH+2*REG_ADDR_WIDTH-1:OPCODE_WIDTH+REG_ADDR_WIDTH];

    wire [REG_ADDR_WIDTH-1:0] alu_dest;
    assign alu_dest = instruction[OPCODE_WIDTH+3*REG_ADDR_WIDTH-1:OPCODE_WIDTH+2*REG_ADDR_WIDTH];

    wire [IMMEDIATE_WIDTH-1:0] load_reg_val;
    assign load_reg_val = instruction[OPCODE_WIDTH+REG_ADDR_WIDTH+12:OPCODE_WIDTH+REG_ADDR_WIDTH];
                    
    
    
    always@(posedge clock)begin
        core_stop <= 0;
        exec_opcode <= 0;
        operand_a_if.valid <= 0;
        operand_b_if.valid <= 0;
        operation_if.valid <= 0;
        if(enable)begin
            exec_opcode <= opcode;
            case(opcode)
                ADD: begin
                    operand_a_if.dest <= operand_a+(2**REG_ADDR_WIDTH*channel_address);
                    operand_a_if.user <= alu_dest+(2**REG_ADDR_WIDTH*channel_address);
                    operand_a_if.valid <= 1;
                    operand_b_if.dest <= operand_b+(2**REG_ADDR_WIDTH*channel_address);
                    operand_b_if.user <= alu_dest+(2**REG_ADDR_WIDTH*channel_address);
                    operand_b_if.valid <= 1;
                    operation_if.data <= 0;
                    operation_if.valid <= 1;
                end
                SUB: begin
                    operand_a_if.dest <= operand_a+(2**REG_ADDR_WIDTH*channel_address);
                    operand_a_if.user <= alu_dest+(2**REG_ADDR_WIDTH*channel_address);
                    operand_a_if.valid <= 1;
                    operand_b_if.dest <= operand_b+(2**REG_ADDR_WIDTH*channel_address);
                    operand_b_if.user <= alu_dest+(2**REG_ADDR_WIDTH*channel_address);
                    operand_b_if.valid <= 1;
                    operation_if.data <= 1;
                    operation_if.valid <= 1;
                end
                MUL: begin
                    operand_a_if.dest <= operand_a+(2**REG_ADDR_WIDTH*channel_address);
                    operand_a_if.user <= alu_dest+(2**REG_ADDR_WIDTH*channel_address);
                    operand_a_if.valid <= 1;
                    operand_b_if.dest <= operand_b+(2**REG_ADDR_WIDTH*channel_address);
                    operand_b_if.user <= alu_dest+(2**REG_ADDR_WIDTH*channel_address);
                    operand_b_if.valid <= 1;
                    operand_b_if.user <= operand_b+(2**REG_ADDR_WIDTH*channel_address);
                end
                REC: begin
                    operand_a_if.dest <= operand_a+(2**REG_ADDR_WIDTH*channel_address);
                    operand_a_if.user <= operand_b+(2**REG_ADDR_WIDTH*channel_address);
                    operand_a_if.valid <= 1;
                end
                FTI:begin
                    operand_b_if.dest <= operand_a+(2**REG_ADDR_WIDTH*channel_address);
                    operand_b_if.user <= operand_b+(2**REG_ADDR_WIDTH*channel_address);
                    operand_b_if.valid <= 1;
                end
                ITF:begin
                    operand_a_if.dest <= operand_a+(2**REG_ADDR_WIDTH*channel_address);
                    operand_a_if.user <= operand_b+(2**REG_ADDR_WIDTH*channel_address);
                    operand_a_if.valid <= 1;
                end
                LDC:begin
                    operand_a_if.dest <= load_data;
                    operand_a_if.user <= operand_a+(2**REG_ADDR_WIDTH*(channel_address));
                    operand_a_if.valid <= 1;
                end
                LDR: begin
                    operand_a_if.dest <= load_reg_val;
                    operand_a_if.user <= operand_a+(2**REG_ADDR_WIDTH*channel_address);
                    operand_a_if.valid <= 1;
                end
                BGT:begin
                    operand_a_if.dest <= operand_a+(2**REG_ADDR_WIDTH*channel_address);
                    operand_a_if.user <= alu_dest+(2**REG_ADDR_WIDTH*channel_address);
                    operand_a_if.valid <= 1;
                    operand_b_if.dest <= operand_b+(2**REG_ADDR_WIDTH*channel_address);
                    operand_b_if.user <= alu_dest+(2**REG_ADDR_WIDTH*channel_address);
                    operand_b_if.valid <= 1;
                    operation_if.data <= 'b100100;
                    operation_if.valid <= 1;
                end
                BLE:begin
                    operand_a_if.dest <= operand_a+(2**REG_ADDR_WIDTH*channel_address);
                    operand_a_if.user <= alu_dest+(2**REG_ADDR_WIDTH*channel_address);
                    operand_a_if.valid <= 1;
                    operand_b_if.dest <= operand_b+(2**REG_ADDR_WIDTH*channel_address);
                    operand_b_if.user <= alu_dest+(2**REG_ADDR_WIDTH*channel_address);
                    operand_b_if.valid <= 1;
                    operation_if.data <= 'b011100;
                    operation_if.valid <= 1;
                end
                BEQ:begin
                    operand_a_if.dest <= operand_a+(2**REG_ADDR_WIDTH*channel_address);
                    operand_a_if.user <= alu_dest+(2**REG_ADDR_WIDTH*channel_address);
                    operand_a_if.valid <= 1;
                    operand_b_if.dest <= operand_b+(2**REG_ADDR_WIDTH*channel_address);
                    operand_b_if.user <= alu_dest+(2**REG_ADDR_WIDTH*channel_address);
                    operand_b_if.valid <= 1;
                    operation_if.data <= 'b010100;
                    operation_if.valid <= 1;
                end
                BNE:begin
                    operand_a_if.dest <= operand_a+(2**REG_ADDR_WIDTH*channel_address);
                    operand_a_if.user <= alu_dest+(2**REG_ADDR_WIDTH*channel_address);
                    operand_a_if.valid <= 1; 
                    operand_b_if.dest <= operand_b+(2**REG_ADDR_WIDTH*channel_address);
                    operand_b_if.user <= alu_dest+(2**REG_ADDR_WIDTH*channel_address);
                    operand_b_if.valid <= 1;
                    operation_if.data <= 'b101100;
                    operation_if.valid <= 1;
                end
                AND:begin
                    operand_a_if.dest <= operand_a+(2**REG_ADDR_WIDTH*channel_address);
                    operand_a_if.user <= alu_dest+(2**REG_ADDR_WIDTH*channel_address);
                    operand_a_if.valid <= 1;
                    operand_b_if.dest <= operand_b+(2**REG_ADDR_WIDTH*channel_address);
                    operand_b_if.user <= alu_dest+(2**REG_ADDR_WIDTH*channel_address);
                    operand_b_if.valid <= 1;
                    operation_if.data <= 0;
                    operation_if.valid <= 1;
                end
                OR:begin
                    operand_a_if.dest <= operand_a+(2**REG_ADDR_WIDTH*channel_address);
                    operand_a_if.user <= alu_dest+(2**REG_ADDR_WIDTH*channel_address);
                    operand_a_if.valid <= 1;
                    operand_b_if.dest <= 5;
                    operand_b_if.dest <= operand_b+(2**REG_ADDR_WIDTH*channel_address);
                    operand_b_if.user <= alu_dest+(2**REG_ADDR_WIDTH*channel_address);
                    operand_b_if.valid <= 1;
                    operation_if.data <= 1;
                    operation_if.valid <= 1;
                end
                NOT:begin
                    operand_a_if.dest <= operand_a+(2**REG_ADDR_WIDTH*channel_address);
                    operand_a_if.user <= operand_b+(2**REG_ADDR_WIDTH*channel_address);
                    operand_a_if.valid <= 1;
                    operation_if.data <= 2;
                    operation_if.valid <= 1;
                end
                SATP:begin
                    operand_a_if.dest <= operand_a+(2**REG_ADDR_WIDTH*channel_address);
                    operand_a_if.user <= alu_dest+(2**REG_ADDR_WIDTH*channel_address);
                    operand_a_if.valid <= 1;
                    operand_b_if.dest <= operand_b+(2**REG_ADDR_WIDTH*channel_address);
                    operand_b_if.user <= alu_dest+(2**REG_ADDR_WIDTH*channel_address);
                    operand_b_if.valid <= 1;
                    operation_if.data <= 1;
                    operation_if.user <= alu_dest+(2**REG_ADDR_WIDTH*channel_address);
                    operation_if.valid <= 1;
                end
                SATN:begin
                    operand_a_if.dest <= operand_a+(2**REG_ADDR_WIDTH*channel_address);
                    operand_a_if.user <= alu_dest+(2**REG_ADDR_WIDTH*channel_address);
                    operand_a_if.valid <= 1;
                    operand_b_if.dest <= operand_b+(2**REG_ADDR_WIDTH*channel_address);
                    operand_b_if.user <= alu_dest+(2**REG_ADDR_WIDTH*channel_address);
                    operand_b_if.valid <= 1;
                    operation_if.data <= 0;
                    operation_if.user <= alu_dest+(2**REG_ADDR_WIDTH*channel_address);
                    operation_if.valid <= 1;
                end
                STOP:begin
                    core_stop <= 1;
                end         
                NOP: begin
                    operand_a_if.dest <= 0;
                    operand_a_if.user <= 0;
                    operand_b_if.dest <= 0;
                    operand_b_if.user <= 0;
                    operation_if.data <= 0;
                    operation_if.dest <= 0;
                    operand_a_if.data <= 0;
                    operand_b_if.data <= 0;
                    operand_a_if.valid <= 0;
                    operand_b_if.valid <= 0;
                    operation_if.valid <= 0;
                    operation_if.user <= 0;
                end
            endcase                        
        end else begin
            operand_a_if.dest <= 0;
            operand_a_if.user <= 0;
            operand_b_if.dest <= 0;
            operand_b_if.user <= 0;
            operation_if.data <= 0;
            operation_if.dest <= 0;
            operand_a_if.data <= 0;
            operand_b_if.data <= 0;
            operand_a_if.valid <= 0;
            operand_b_if.valid <= 0;
            operation_if.valid <= 0;
            operation_if.user <= 0;
        end
        
    end

    
endmodule
