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
import fcore_isa::*;

module fCore_FP_ALU #(
    parameter DATAPATH_WIDTH =32,
    PIPELINE_DEPTH=5,
    OPCODE_WIDTH=8, 
    REGISTER_ADDR_WIDTH = 8,
    RECIPROCAL_PRESENT=0,
    BITMANIP_IMPLEMENTED = 0,
    LOGIC_IMPLEMENTED = 0,
    FULL_COMPARE = 1,
    CONDITIONAL_SELECT_IMPLEMENTED = 1
)(
    input wire clock,
    input wire reset,
    input wire [OPCODE_WIDTH-1:0] opcode,
    axi_stream.slave operand_a,
    axi_stream.slave operand_b,
    axi_stream.slave operand_c,
    axi_stream.slave operation,
    axi_stream.master result 
);


    reg [OPCODE_WIDTH-1:0] opcode_del = 0;

    always_ff@(posedge clock) begin
        opcode_del <= opcode;
    end
    
    axi_stream #(
        .USER_WIDTH(REGISTER_ADDR_WIDTH)
    ) add_result();
    
    axi_stream #(
        .USER_WIDTH(REGISTER_ADDR_WIDTH)
    ) reciprocal_result();

    axi_stream #(
        .USER_WIDTH(REGISTER_ADDR_WIDTH)
    ) mul_result();

    axi_stream #(
        .USER_WIDTH(REGISTER_ADDR_WIDTH)
    ) fti_result();

    axi_stream #(
        .USER_WIDTH(REGISTER_ADDR_WIDTH)
    ) itf_result();

    axi_stream #(
        .USER_WIDTH(REGISTER_ADDR_WIDTH)
    ) logic_result();
 
    axi_stream #(
        .USER_WIDTH(REGISTER_ADDR_WIDTH)
    ) comparison_result();

    axi_stream #(
        .USER_WIDTH(REGISTER_ADDR_WIDTH)
    ) saturation_result();

    axi_stream #(
        .USER_WIDTH(REGISTER_ADDR_WIDTH)
    ) ldc_operand_a();

    axi_stream #(
        .USER_WIDTH(REGISTER_ADDR_WIDTH)
    ) bitmanip_result();

    axi_stream #(
        .USER_WIDTH(REGISTER_ADDR_WIDTH)
    ) abs_result();
 
    axi_stream #(
        .USER_WIDTH(REGISTER_ADDR_WIDTH)
    ) csel_result();
 

    wire add_enable;
    assign add_enable = (opcode_del == fcore_isa::ADD | opcode_del == fcore_isa::SUB);
    wire rec_enable;
    assign rec_enable = (opcode_del == fcore_isa::REC);
    wire mul_enable;
    assign mul_enable = (opcode_del == fcore_isa::MUL);
    wire fti_enable;
    assign fti_enable = (opcode_del == fcore_isa::FTI);
    wire itf_enable;
    assign itf_enable = (opcode_del == fcore_isa::ITF);
    wire ldc_enable;
    assign ldc_enable = (opcode_del == fcore_isa::LDC);
    wire abs_enable;
    assign abs_enable = (opcode_del == fcore_isa::ABS);
    wire csel_enable;
    assign csel_enable = (opcode_del == fcore_isa::CSEL);
    wire logic_enable;
    assign logic_enable = (opcode_del == fcore_isa::LAND | opcode_del == fcore_isa::LOR | opcode_del == fcore_isa::LXOR | opcode_del == fcore_isa::LNOT);
    wire bitmanip_enable;
    assign bitmanip_enable =  opcode_del == fcore_isa::POPCNT| opcode_del == fcore_isa::BSET | opcode_del == fcore_isa::BSEL;
    wire sat_enable;
    assign sat_enable = opcode_del == fcore_isa::SATN | opcode_del == fcore_isa::SATP;
    wire compare_enable;
    assign compare_enable = opcode_del == fcore_isa::BGT | opcode_del == fcore_isa::BLE | opcode_del == fcore_isa::BEQ | opcode_del == fcore_isa::BNE;

        fcore_adder_ip adder (
            .clock(clock),
            .reset(reset),
            .enable(add_enable),
            .operand_a(operand_a),
            .operand_b(operand_b),
            .operation(operation),
            .result(add_result)
        );

        fcore_itf_ip itf (
            .clock(clock),
            .reset(reset),
            .enable(itf_enable),
            .operand_a(operand_a),
            .result(itf_result)
        );


        fcore_fti_ip fti (
            .clock(clock),
            .reset(reset),
            .enable(fti_enable),
            .operand_a(operand_b),
            .result(fti_result)
        );

        fcore_multiplier_ip multiplier (
            .clock(clock),
            .reset(reset),
            .enable(mul_enable),
            .operand_a(operand_a),
            .operand_b(operand_b),
            .result(mul_result)
        );


    generate 
        if(RECIPROCAL_PRESENT==1)begin

        
            fcore_reciprocal_ip reciprocal (
                .clock(clock),
                .reset(reset),
                .enable(rec_enable),
                .operand_a(operand_a),
                .result(reciprocal_result)
            );

        end 
        
    endgenerate  



    alu_results_combiner #(
        .REGISTERED(0)
    )combiner (
        .clock(clock),
        .reset(reset),
        .add_result(add_result),
        .mul_result(mul_result),
        .rec_result(reciprocal_result),
        .fti_result(fti_result),
        .itf_result(itf_result),
        .sat_result(saturation_result),
        .logic_result(logic_result),
        .comparison_result(comparison_result),
        .load_result(ldc_operand_a),
        .bitmanip_result(bitmanip_result),
        .abs_result(abs_result),
        .csel_result(csel_result),
        .result(result)
    );

 
 
    ////////////////////////////////////////////////
    //              ABSOLUTE VALUE                //
    ////////////////////////////////////////////////
    
    always_ff@(posedge clock) begin
        abs_result.valid <= 0;
        abs_result.user <= 0;
        abs_result.data <= 0;
        if(operand_a.valid & abs_enable)begin
            case(operation.data)
                4:begin
                    abs_result.valid <= 1;
                    abs_result.user <= operand_a.user;
                    abs_result.data <= {0, operand_a.data[30:0]};  
                end
            endcase
        end
    end


    ////////////////////////////////////////////////
    //              ABSOLUTE VALUE                //
    ////////////////////////////////////////////////
    
    generate
        if(CONDITIONAL_SELECT_IMPLEMENTED==1)begin
            always_ff@(posedge clock) begin
                csel_result.valid <= 0;
                csel_result.user <= 0;
                csel_result.data <= 0;
                if(operand_a.valid & csel_enable)begin
                    csel_result.valid <= 1;
                    csel_result.user <= operand_a.user;
                    csel_result.data <= operand_a.data[0] ? operand_b.data : operand_c.data;  
                end
            end

        end
    endgenerate

    ////////////////////////////////////////////////
    //                   LOGIC                    //
    ////////////////////////////////////////////////
    generate
        if(LOGIC_IMPLEMENTED==1)begin
            fCore_logic_unit logic_engine (
                .clock(clock),
                .reset(reset),
                .enable(logic_enable),
                .operand_a(operand_a),
                .operand_b(operand_b),
                .operand_c(operand_c),
                .operation(operation),
                .result(logic_result) 
            );
        end
    endgenerate
    ////////////////////////////////////////////////
    //                  BITMANIP                  //
    ////////////////////////////////////////////////
    
    generate
        if(BITMANIP_IMPLEMENTED==1)begin
            fCore_bitmanip_unit  bitmanip_engine (
                .clock(clock),
                .reset(reset),
                .enable(bitmanip_enable),
                .operand_a(operand_a),
                .operand_b(operand_b),
                .operand_c(operand_c),
                .operation(operation),
                .result(bitmanip_result) 
            );
        end
    endgenerate


    ////////////////////////////////////////////////
    //                  SATURATION                //
    ////////////////////////////////////////////////

    FP_saturator #(
        .DATA_WIDTH(32),
        .REG_ADDR_WIDTH(REGISTER_ADDR_WIDTH),
        .SELCTION_DEST(0)
    ) saturator(
        .clock(clock),
        .reset(reset),
        .enable(sat_enable),
        .operand_a(operand_a.data),
        .operand_b(operand_b.data),
        .operation(operation),
        .result(saturation_result)
    );

    ////////////////////////////////////////////////
    //                  COMPARISON                //
    ////////////////////////////////////////////////

    fCore_compare_unit #(
        .FULL_COMPARE(FULL_COMPARE)
    )compare_unit(
        .clock(clock),
        .reset(reset),
        .enable(compare_enable),
        .operand_a(operand_a),
        .operand_b(operand_b),
        .operand_c(operand_c),
        .operation(operation),
        .result(comparison_result)
    );

    ////////////////////////////////////////////////
    //                    LDC/LDR                 //
    ////////////////////////////////////////////////
    always_ff@(posedge clock) begin
        ldc_operand_a.valid <= operand_a.valid & ldc_enable;
        ldc_operand_a.data <= operand_a.dest;
        ldc_operand_a.dest <= operand_a.user;
    end

endmodule