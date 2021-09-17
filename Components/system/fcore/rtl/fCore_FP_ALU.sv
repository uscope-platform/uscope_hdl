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

module fCore_FP_ALU #(parameter DATAPATH_WIDTH =32, PIPELINE_DEPTH=5, OPCODE_WIDTH=8, REGISTER_ADDR_WIDTH = 8, RECIPROCAL_PRESENT=0)(
    input wire clock,
    input wire reset,
    input wire [OPCODE_WIDTH-1:0] result_select,
    axi_stream.slave operand_a,
    axi_stream.slave operand_b,
    axi_stream.slave operation,
    axi_stream.master result 
);


    defparam add_result.USER_WIDTH = REGISTER_ADDR_WIDTH;
    axi_stream add_result();
    
    defparam reciprocal_result.USER_WIDTH = REGISTER_ADDR_WIDTH;
    axi_stream reciprocal_result();

    defparam mul_result.USER_WIDTH = REGISTER_ADDR_WIDTH;
    axi_stream mul_result();

    defparam cmp_result.USER_WIDTH = REGISTER_ADDR_WIDTH;
    axi_stream cmp_result();

    defparam fti_result.USER_WIDTH = REGISTER_ADDR_WIDTH;
    axi_stream fti_result();

    defparam itf_result.USER_WIDTH = REGISTER_ADDR_WIDTH;
    axi_stream itf_result();

    defparam logic_result.USER_WIDTH = REGISTER_ADDR_WIDTH;
    axi_stream logic_result();
 
    defparam early_logic_result.USER_WIDTH = REGISTER_ADDR_WIDTH;
    axi_stream early_logic_result();

    defparam saturation_result.USER_WIDTH = REGISTER_ADDR_WIDTH;
    axi_stream saturation_result();

    defparam early_saturation_result.USER_WIDTH = REGISTER_ADDR_WIDTH;
    axi_stream early_saturation_result();

    defparam ldr_operand_a.USER_WIDTH = REGISTER_ADDR_WIDTH;
    axi_stream ldr_operand_a();

    defparam ldc_adj_a.USER_WIDTH = REGISTER_ADDR_WIDTH;
    axi_stream ldc_adj_a();

    defparam ldc_operand_a.USER_WIDTH = REGISTER_ADDR_WIDTH;
    axi_stream ldc_operand_a();
    /*   THERE IS A BUG IN VIVADO WHERE THIS CONDITIONAL CRASHES SYNTHESIS (2020.2 and 2021.1)
         UNTIL IT IS SOLVED THE CORRECT ALU MUST BE COPY PASTED BELOW
    generate 
        if(RECIPROCAL_PRESENT==1)begin
        

        div_alu_wrapper div_alu (
            .clock(clock),
            .reset(reset),
            .operand_a(operand_a),
            .operand_b(operand_b),
            .operation(operation),
            .add_result(add_result),
            .cmp_result(cmp_result),
            .fti_result(fti_result),
            .itf_result(itf_result),
            .mul_result(mul_result),
            .reciprocal_result(reciprocal_result)
        );


        end else begin

            simple_alu_wrapper simple_alu (
                .clock(clock),
                .reset(reset),
                .operand_a(operand_a),
                .operand_b(operand_b),
                .operation(operation),
                .add_result(add_result),
                .cmp_result(cmp_result),
                .fti_result(fti_result),
                .itf_result(itf_result),
                .mul_result(mul_result)
            );    
        end
        
    endgenerate
    */

    simple_alu_wrapper simple_alu (
        .clock(clock),
        .reset(reset),
        .operand_a(operand_a),
        .operand_b(operand_b),
        .operation(operation),
        .add_result(add_result),
        .cmp_result(cmp_result),
        .fti_result(fti_result),
        .itf_result(itf_result),
        .mul_result(mul_result)
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

    always_comb begin

        case (result_select)
            ADD,
            SUB: begin
                result.data <= add_result.data;
                result.dest <= add_result.user;
                result.valid <= 1;
            end
            MUL:begin
                result.data <= mul_result.data;
                result.dest <= mul_result.user;
                result.valid <= 1;          
            end
            REC:begin
                result.data <= reciprocal_result.data;
                result.dest <= reciprocal_result.user;
                result.valid <= 1;       
            end
            LDR:begin
                result.data <= ldr_operand_a.dest;
                result.dest <= ldr_operand_a.user;
                result.valid <= 1;     
            end
            LDC:begin
                result.data <= ldc_operand_a.dest;
                result.dest <= ldc_operand_a.user;
                result.valid <= 1;
            end
            BGT,
            BLE,
            BEQ,
            BNE: begin
                result.data <= cmp_result.data;
                result.dest <= cmp_result.user;
                result.valid <= 1;
            end
            FTI:begin
                result.data <= fti_result.data;
                result.dest <= fti_result.user;
                result.valid <= 1;
            end
            ITF: begin
                result.data <= itf_result.data;
                result.dest <= itf_result.user;
                result.valid <= 1;
            end
            AND,
            OR,
            NOT:begin
                result.data <= logic_result.data;
                result.dest <= logic_result.user;
                result.valid <= 1;
            end
            SATN,
            SATP:begin
                result.data <= saturation_result.data;
                result.dest <= saturation_result.user;
                result.valid <= 1;
            end
            default: begin
                result.data <= 0;
                result.dest <= 0;
                result.valid <= 0;
            end
        endcase
    end

    always@(posedge clock) begin
        early_logic_result.valid <= 0;
        early_logic_result.user <= 0;
        early_logic_result.data <= 0;
        if(operand_a.valid)begin
            case(operation.data)
                0:begin
                    early_logic_result.data <= operand_a.data & operand_b.data;
                    early_logic_result.user <= operand_a.user;
                    early_logic_result.valid <= 1;                 
                end
                1:begin
                    early_logic_result.valid <= 1;
                    early_logic_result.user <= operand_a.user;
                    early_logic_result.data <= operand_a.data | operand_b.data;
                end
                2:begin
                    early_logic_result.valid <= 1;
                    early_logic_result.user <= operand_a.user;
                    early_logic_result.data <= ~operand_a.data;                     
                end
            endcase
        end
    end

   register_slice #(
        .DATA_WIDTH(32),
        .DEST_WIDTH(32),
        .USER_WIDTH(32),
        .N_STAGES(PIPELINE_DEPTH-1),
        .READY_REG(0)
   ) logic_pipeline_adapter (
        .clock(clock),
        .reset(reset),
        .in(early_logic_result),
        .out(logic_result)
    );

    FP_saturator #(
        .DATA_WIDTH(32),
        .REG_ADDR_WIDTH(REGISTER_ADDR_WIDTH),
        .SELCTION_DEST(0)
    ) saturator(
        .clock(clock),
        .reset(reset),
        .operand_a(operand_a.data),
        .operand_b(operand_b.data),
        .operation(operation),
        .result(early_saturation_result)
    );

    register_slice #(
        .DATA_WIDTH(32),
        .DEST_WIDTH(32),
        .USER_WIDTH(32),
        .N_STAGES(PIPELINE_DEPTH-2),
        .READY_REG(0)
    ) sat_pipeline_adapter (
        .clock(clock),
        .reset(reset),
        .in(early_saturation_result),
        .out(saturation_result)
    );

    register_slice #(
        .DATA_WIDTH(32),
        .DEST_WIDTH(32),
        .USER_WIDTH(32),
        .N_STAGES(PIPELINE_DEPTH),
        .READY_REG(0)
    ) load_register_pipeline (
        .clock(clock),
        .reset(reset),
        .in(operand_a),
        .out(ldr_operand_a)
    );




    assign ldc_adj_a.valid = operand_a.valid;
    assign ldc_adj_a.dest = operand_a.dest;
    always_ff@(posedge clock)begin
        ldc_adj_a.user <= operand_a.user;
    end




    register_slice #(
        .DATA_WIDTH(32),
        .DEST_WIDTH(32),
        .USER_WIDTH(32),
        .N_STAGES(PIPELINE_DEPTH-2),
        .READY_REG(0)
    ) load_constant_pipeline (
        .clock(clock),
        .reset(reset),
        .in(ldc_adj_a),
        .out(ldc_operand_a)
    );

endmodule