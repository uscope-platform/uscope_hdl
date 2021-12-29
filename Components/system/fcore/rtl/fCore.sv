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
    output wire done,
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
    

    ///////////////////////////////
    //        PIPELINE           //
    ///////////////////////////////

    axi_stream operand_a();
    axi_stream operand_a_dly();
    axi_stream operand_b();
    axi_stream operand_b_dly();
    axi_stream operation();
    axi_stream operation_dly();
    axi_stream result();
    wire core_stop, decoder_enable, alu_execute;
    wire dma_enable;
    wire [ADDR_WIDTH-1:0] program_counter;

    wire [2*INSTRUCTION_WIDTH-1:0] instruction_w;
    wire [INSTRUCTION_WIDTH-1:0] instruction;
    wire [INSTRUCTION_WIDTH-1:0] load_data;
    wire [ALU_OPCODE_WIDTH-1:0] exec_opcode;

    wire [DATAPATH_WIDTH-1:0] operand_data_a;
    wire [DATAPATH_WIDTH-1:0] operand_data_b;    

    wire [REG_ADDR_WIDTH-1:0] dma_read_addr;
    wire [DATAPATH_WIDTH-1:0] dma_read_data;

    wire [REG_ADDR_WIDTH-1:0] dma_write_addr;
    wire [DATAPATH_WIDTH-1:0] dma_write_data;
    wire dma_write_valid;

    wire immediate_advance;
    wire [CH_ADDRESS_WIDTH-1:0] channel_address_cu;
    wire [CH_ADDRESS_WIDTH-1:0] channel_address;
    wire [CH_ADDRESS_WIDTH-1:0] n_channels;

    defparam control_unit.MAX_CHANNELS = MAX_CHANNELS;
    defparam control_unit.PC_WIDTH = ADDR_WIDTH;
    fCore_ControlUnit control_unit (
        .clock(clock),
        .run(run),
        .immediate_advance(immediate_advance),
        .core_stop(core_stop),
        .n_channels(n_channels),
        .program_counter(program_counter),
        .decoder_enable(decoder_enable),
        .dma_enable(dma_enable),
        .channel_address(channel_address_cu),
        .done(done)
    );


    fCore_prefetcher #(
        .INSTRUCTION_WIDTH(INSTRUCTION_WIDTH),
        .MAX_CHANNELS(MAX_CHANNELS)
    ) pre_fetcher(
        .clock(clock),
        .reset(reset),
        .run(run),
        .channel_address_in(channel_address_cu),
        .n_channels(n_channels),
        .instruction_in(instruction_w),
        .instruction_out(instruction),
        .load_data(load_data),
        .channel_address_out(channel_address),
        .immediate_advance(immediate_advance)
    );



    defparam decoder.INSTRUCTION_WIDTH = INSTRUCTION_WIDTH;
    defparam decoder.DATAPATH_WIDTH = DATAPATH_WIDTH;
    defparam decoder.PC_WIDTH = ADDR_WIDTH;
    defparam decoder.OPCODE_WIDTH = OPCODE_WIDTH;
    defparam decoder.REG_ADDR_WIDTH=BASE_REG_ADDR_WIDTH;
    defparam decoder.CHANNEL_ADDR_WIDTH=CH_ADDRESS_WIDTH;
    defparam decoder.MAX_CHANNELS = MAX_CHANNELS; 
    fCore_decoder decoder (
        .clock(clock),
        .reset(reset),
        .enable(decoder_enable),
        .instruction(instruction),
        .load_data(load_data),
        .n_channels(n_channels),
        .channel_address(channel_address),
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


    defparam executor.OPCODE_WIDTH = ALU_OPCODE_WIDTH;
    defparam executor.REG_ADDR_WIDTH = REG_ADDR_WIDTH;
    defparam executor.DATA_WIDTH = DATAPATH_WIDTH;
    defparam executor.RECIPROCAL_PRESENT = RECIPROCAL_PRESENT;
    fCore_exec executor (
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
    defparam dma_ep.BASE_ADDRESS = DMA_BASE_ADDRESS;
    defparam dma_ep.DATAPATH_WIDTH = DATAPATH_WIDTH;
    defparam dma_ep.PULSE_STRETCH_LENGTH = 4;
    defparam dma_ep.REG_ADDR_WIDTH = REG_ADDR_WIDTH;

    fCore_dma_endpoint dma_ep(
        .clock(clock),
        .reset(reset),
        .axi_in(control_axi_in),
        .dma_read_addr(dma_read_addr),
        .dma_read_data(dma_read_data),
        .dma_write_addr(dma_write_addr),
        .dma_write_data(dma_write_data),
        .dma_write_valid(dma_write_valid),
        .n_channels(n_channels),
        .axis_dma_write(axis_dma_write),
        .axis_dma_read_request(axis_dma_read_request),
        .axis_dma_read_response(axis_dma_read_response)
        );

    defparam store.DATA_WIDTH = INSTRUCTION_WIDTH;
    defparam store.MEM_DEPTH = INSTRUCTION_STORE_SIZE;
    defparam store.REGISTERED = "TRUE";
    defparam store.FAST_DEBUG = FAST_DEBUG;
    defparam store.INIT_FILE = INIT_FILE;
    fCore_Istore store(
        .clock(clock),
        .reset(reset),
        .dma_read_addr(program_counter),
        .dma_read_data_w(instruction_w),
        .axi(axi)
    );

    defparam registers.REGISTER_WIDTH = DATAPATH_WIDTH;
    defparam registers.FILE_DEPTH = REGISTER_FILE_DEPTH*MAX_CHANNELS;
    defparam registers.REG_PER_CHANNEL = REGISTER_FILE_DEPTH;
    fCore_registerFile registers(
        .clock(clock),
        .reset(reset),
        .write_if(result),
        .dma_enable(dma_enable),
        .read_addr_a(operand_a.dest),
        .read_data_a(operand_data_a),
        .read_addr_b(operand_b.dest),
        .read_data_b(operand_data_b),
        .dma_read_addr(dma_read_addr),
        .dma_read_data(dma_read_data),
        .dma_write_addr(dma_write_addr),
        .dma_write_data(dma_write_data),
        .dma_write_valid(dma_write_valid)
    );

    
endmodule
