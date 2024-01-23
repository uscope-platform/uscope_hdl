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
`timescale 10ns / 1ns
`include "interfaces.svh"

module uScope_dma #(
    N_TRIGGERS = 16,
    DATA_WIDTH = 32,
    DEST_WIDTH = 8,
    N_STREAMS = 6,
    OUTPUT_AXI_WIDTH = 128,
    MAX_TRANSFER_SIZE = 8192
)(
    input wire clock,
    input wire reset,
    output wire dma_done,
    output wire [N_TRIGGERS-1:0] trigger_out,
    axi_stream.slave stream_in[N_STREAMS],
    AXI.master out,
    axi_lite.slave axi_in
);

    localparam CHANNEL_BUFFER_SIZE = 1024; 

    axi_stream #(
        .DATA_WIDTH(DATA_WIDTH)
    ) combined();
    
    axi_stream #(
        .DATA_WIDTH(DATA_WIDTH)
    ) combined_tlast();
   
    reg dma_enable;
    wire capture_inhibit;

    reg [63:0] dma_base_addr;

    reg [31:0] tlast_period;
    wire [15:0] current_sample;

    wire trigger;
    reg [31:0] cu_write_registers [5:0];
    reg [31:0] cu_read_registers [5:0];
    axil_simple_register_cu #(
        .N_READ_REGISTERS(6),
        .N_WRITE_REGISTERS(6),
        .REGISTERS_WIDTH(32),
        .N_TRIGGER_REGISTERS(1),
        .TRIGGER_REGISTERS_IDX({3}),
        .ADDRESS_MASK('h1f)
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(cu_read_registers),
        .output_registers(cu_write_registers),
        .trigger_out(trigger),
        .axil(axi_in)
    );
    

    reg [31:0] selected_trigger;
    reg capture_ack;
    reg [15:0] trigger_position;

    assign tlast_period = cu_write_registers[0];
    assign dma_enable = cu_write_registers[1];
    assign dma_base_addr[31:0] = cu_write_registers[2];
    assign dma_base_addr[63:32] = cu_write_registers[3];
    assign selected_trigger = cu_write_registers[4];
    assign capture_ack = cu_write_registers[5][0];
    assign trigger_position = cu_write_registers[6];


    assign cu_read_registers[0] = tlast_period;
    assign cu_read_registers[1] = dma_enable;
    assign cu_read_registers[2] = dma_base_addr[31:0];
    assign cu_read_registers[3] = dma_base_addr[63:32];
    assign cu_read_registers[4] = selected_trigger;
    assign cu_read_registers[5] = {31'b0, capture_ack};
    assign cu_read_registers[6] = {16'b0, trigger_position};


    trigger_hub #(
        .N_TRIGGERS(N_TRIGGERS) 
    ) triggers (
        .clock(clock),
        .reset(reset),
        .buffer_level(current_sample),
        .capture_done(combined_tlast.tlast),
        .trigger_in(trigger),
        .selected_trigger(selected_trigger),
        .trigger_position(trigger_position),
        .capture_ack(capture_ack),
        .capture_inhibit(capture_inhibit),
        .trigger_out(trigger_out)
    );

    axi_stream_combiner_ub #(
        .INPUT_DATA_WIDTH(DATA_WIDTH), 
        .OUTPUT_DATA_WIDTH(DATA_WIDTH), 
        .DEST_WIDTH(DEST_WIDTH),
        .N_STREAMS(N_STREAMS)
    )combiner(
        .clock(clock),
        .reset(reset),
        .stream_in(stream_in),
        .stream_out(combined)
    );
        
    tlast_generator_sv tlast_gen(
        .clock(clock),
        .reset(reset), 
        .period(tlast_period),
        .disable_gen(capture_inhibit),
        .current_sample(current_sample),
        .data_in(combined),
        .data_out(combined_tlast)
    );

    axi_dma #(
        .ADDR_WIDTH(64),
        .OUTPUT_AXI_WIDTH(OUTPUT_AXI_WIDTH),
        .DEST_WIDTH(DEST_WIDTH),
        .MAX_TRANSFER_SIZE(MAX_TRANSFER_SIZE)
    )dma_engine(
        .clock(clock),
        .reset(reset),
        .enable(dma_enable),
        .dma_base_addr(dma_base_addr),
        .data_in(combined_tlast),
        .axi_out(out),
        .dma_done(dma_done)
    );


endmodule

    /**
       {
        "name": "uScope_dma",
        "type": "peripheral",
        "registers":[
            {
                "name": "buffer_size",
                "offset": "0x0",
                "description": "Size of the scope buffer in words",
                "direction": "RW"
            },
            {
                "name": "enable",
                "offset": "0x4",
                "description": "Address of the first word in memory of the data buffer",
                "direction": "RW"
            },
            {
                "name": "buffer_addr_low",
                "offset": "0x8",
                "description": "Writing 1 to this register enables the scope",
                "direction": "RW"  
            },
            {
                "name": "buffer_addr_high",
                "offset": "0xC",
                "description": "Writing 1 to this register enables the scope",
                "direction": "RW"  
            },
            {
                "name": "selected_trigger",
                "offset": "0x10",
                "description": "Writing an address to this register triggers the related signal",
                "direction": "RW"  
            },
            {
                "name": "capture_ack",
                "offset": "0x14",
                "description": "Acknowledge the last captured trigger",
                "direction": "RW"  
            },
            {
                "name": "trigger_position",
                "offset": "0x18",
                "description": "Position of the trigger in the capture window",
                "direction": "RW"  
            }
        ]
    }  
    **/
