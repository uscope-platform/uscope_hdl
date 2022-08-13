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

module fCore(
    input wire clock,
    input wire reset,
    input wire run,
    input wire efi_done,
    output wire done,
    output wire efi_start,
    axi_stream.master efi_arguments,
    axi_stream.slave efi_results,

    axi_lite.slave control_axi_in,
    AXI.slave axi,
    axi_stream.slave axis_dma_write,
    axi_stream.slave axis_dma_read_request,
    axi_stream.master axis_dma_read_response
);

    parameter FAST_DEBUG = "TRUE";
    parameter INIT_FILE = "init.mem";
    parameter DMA_BASE_ADDRESS = 32'h43c00000;
    parameter INSTRUCTION_STORE_SIZE = 4096;
    parameter INSTRUCTION_WIDTH = 32;
    parameter DATAPATH_WIDTH = 32;
    parameter ALU_OPCODE_WIDTH = 5;
    parameter OPCODE_WIDTH = 5;
    parameter REGISTER_FILE_DEPTH = 64;
    parameter RECIPROCAL_PRESENT = 0;
    
    // Maximum number of supported channels
    parameter MAX_CHANNELS = 4;

    // Width of the instruction address
    localparam ADDR_WIDTH = $clog2(INSTRUCTION_STORE_SIZE);
    
    // Width of the address for the single channel register file
    localparam BASE_REG_ADDR_WIDTH = $clog2(REGISTER_FILE_DEPTH);
    
    // Additional register address width due to the channelisation
    localparam CH_ADDRESS_WIDTH = $clog2(MAX_CHANNELS);
    
    // Overall register address width
    localparam REG_ADDR_WIDTH = BASE_REG_ADDR_WIDTH+CH_ADDRESS_WIDTH;
    
    // Size of the register file
    localparam REG_FILE_SIZE = REGISTER_FILE_DEPTH*MAX_CHANNELS;
    ///////////////////////////////
    //        PIPELINE           //
    ///////////////////////////////

    axi_stream operand_a();
    axi_stream operand_a_dly();
    axi_stream operand_b();
    axi_stream operand_b_dly();
    axi_stream #(
        .DATA_WIDTH(8)
    ) operation();
    axi_stream #(
        .DATA_WIDTH(8)
    ) operation_dly();
    axi_stream result();
    wire core_stop, decoder_enable;
    wire dma_enable;
    wire [ADDR_WIDTH-1:0] program_counter;

    wire [2*INSTRUCTION_WIDTH-1:0] instruction_w;
    wire [INSTRUCTION_WIDTH-1:0] load_data;
    wire [ALU_OPCODE_WIDTH-1:0] exec_opcode;

    wire [DATAPATH_WIDTH-1:0] operand_data_a;
    wire [DATAPATH_WIDTH-1:0] operand_data_b;    

    wire [REG_ADDR_WIDTH-1:0] dma_read_addr;
    wire [DATAPATH_WIDTH-1:0] dma_read_data;

    wire [REG_ADDR_WIDTH-1:0] efi_read_addr;
    wire [DATAPATH_WIDTH-1:0] efi_read_data;

    wire immediate_advance;
    wire [1:0] mem_efi_enable;
    wire [CH_ADDRESS_WIDTH-1:0] n_channels;

    axi_stream instruction_stream();
    
    fCore_ControlUnit #(
        .MAX_CHANNELS(MAX_CHANNELS),
        .PC_WIDTH(ADDR_WIDTH),
        .INSTRUCTION_WIDTH(INSTRUCTION_WIDTH)
    ) control_unit (
        .clock(clock),
        .reset(reset),
        .run(run),
        .efi_done(efi_done),
        .efi_start(efi_start),
        .core_stop(core_stop),
        .wide_instruction_in(instruction_w),
        .n_channels(n_channels),
        .program_counter(program_counter),
        .load_data(load_data),
        .decoder_enable(decoder_enable),
        .dma_enable(dma_enable),
        .done(done),
        .instruction_stream(instruction_stream)
    );

    fCore_decoder #(
        .INSTRUCTION_WIDTH(INSTRUCTION_WIDTH),
        .DATAPATH_WIDTH(DATAPATH_WIDTH),
        .PC_WIDTH(ADDR_WIDTH),
        .OPCODE_WIDTH(OPCODE_WIDTH),
        .REG_ADDR_WIDTH(BASE_REG_ADDR_WIDTH),
        .CHANNEL_ADDR_WIDTH(CH_ADDRESS_WIDTH),
        .MAX_CHANNELS(MAX_CHANNELS)
    ) decoder (
        .clock(clock),
        .reset(reset),
        .enable(decoder_enable),
        .instruction_stream(instruction_stream),
        .load_data(load_data),
        .n_channels(n_channels),
        .exec_opcode(exec_opcode),
        .core_stop(core_stop),
        .operand_a_if(operand_a),
        .operand_b_if(operand_b),
        .operation_if(operation)
    );


    assign operand_a.ready = operand_a_dly.ready;
    assign operand_b.ready = operand_b_dly.ready;
    
    assign operand_a_dly.data = operand_data_a;
    assign operand_b_dly.data = operand_data_b;

    register_slice #(
        .DATA_WIDTH(32),
        .DEST_WIDTH(32),
        .USER_WIDTH(32),
        .N_STAGES(1),
        .READY_REG(0)
    ) reg_operation (
        .clock(clock),
        .reset(reset),
        .in(operation),
        .out(operation_dly)
    );

    always@(posedge clock)begin

        operand_a_dly.dest <= operand_a.dest;
        operand_a_dly.user <= operand_a.user;
        operand_a_dly.valid <= operand_a.valid;

        operand_b_dly.dest <= operand_b.dest;
        operand_b_dly.user <= operand_b.user;
        operand_b_dly.valid <= operand_b.valid;
    end



    fCore_exec #( 
        .OPCODE_WIDTH(ALU_OPCODE_WIDTH),
        .REG_ADDR_WIDTH(REG_ADDR_WIDTH),
        .DATA_WIDTH(DATAPATH_WIDTH),
        .RECIPROCAL_PRESENT(RECIPROCAL_PRESENT)
    ) executor (
        .clock(clock),
        .reset(reset),
        .opcode(exec_opcode),
        .operand_a(operand_a_dly),
        .operand_b(operand_b_dly),
        .operation(operation_dly),
        .result(result)
    );

    
    ///////////////////////////////
    //      AUXILIARY BLOCKS     //
    ///////////////////////////////
    
    axi_stream efi_writeback();

    fCore_efi_memory_handler #(
        .DATAPATH_WIDTH(DATAPATH_WIDTH),
        .REG_ADDR_WIDTH(REG_ADDR_WIDTH),
        .BASE_REG_ADDR_WIDTH(BASE_REG_ADDR_WIDTH),
        .CH_ADDRESS_WIDTH(CH_ADDRESS_WIDTH)
    )efi_handler(
        .clock(clock),
        .reset(reset),
        .send_arguments(efi_start),
        .arguments_base_address(operand_a.user),
        .return_base_address(operand_b.dest),
        .channel_address(instruction_stream.dest), 
        .length(operand_a.dest),
        .mem_address(efi_read_addr),
        .mem_read_data(efi_read_data),
        .mem_efi_enable(mem_efi_enable),
        .efi_arguments(efi_arguments),
        .efi_results(efi_results),
        .result_writeback(efi_writeback)
    );
    
    axi_stream dma_write();

    fCore_dma_endpoint #( 
        .BASE_ADDRESS(DMA_BASE_ADDRESS),
        .DATAPATH_WIDTH(DATAPATH_WIDTH),
        .REG_ADDR_WIDTH(REG_ADDR_WIDTH)
    )dma_ep(
        .clock(clock),
        .reset(reset),
        .axi_in(control_axi_in),
        .dma_read_addr(dma_read_addr),
        .dma_read_data(dma_read_data),
        .reg_dma_write(dma_write),
        .n_channels(n_channels),
        .axis_dma_write(axis_dma_write),
        .axis_dma_read_request(axis_dma_read_request),
        .axis_dma_read_response(axis_dma_read_response)
    );

    fCore_Istore #(
        .DATA_WIDTH(INSTRUCTION_WIDTH),
        .MEM_DEPTH(INSTRUCTION_STORE_SIZE),
        .REGISTERED("TRUE"),
        .FAST_DEBUG(FAST_DEBUG),
        .INIT_FILE(INIT_FILE)
    ) store(
        .clock(clock),
        .reset(reset),
        .dma_read_addr(program_counter),
        .dma_read_data_w(instruction_w),
        .axi(axi)
    );

    fCore_registerFile #(
        .REGISTER_WIDTH(DATAPATH_WIDTH),
        .FILE_DEPTH(REG_FILE_SIZE),
        .REG_PER_CHANNEL(REGISTER_FILE_DEPTH)
    ) registers(
        .clock(clock),
        .reset(reset),
        .write_if(result),
        .dma_enable(dma_enable),
        .efi_enable(mem_efi_enable),
        .read_addr_a(operand_a.dest),
        .read_data_a(operand_data_a),
        .read_addr_b(operand_b.dest),
        .read_data_b(operand_data_b),
        .dma_read_addr(dma_read_addr),
        .dma_read_data(dma_read_data),
        .efi_read_addr(efi_read_addr),
        .efi_read_data(efi_read_data),
        .dma_write(dma_write),
        .efi_write(efi_writeback)
    );
    
endmodule
