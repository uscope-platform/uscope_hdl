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


module uScope_stream #(
    N_TRIGGERS = 1,
    BASE_ADDRESS = 0,
    DATA_WIDTH = 32,
    ADDR_WIDTH = 32,
    DEST_WIDTH = 8,
    MAX_TRANSFER_SIZE = 8192
) (
    input wire clock,
    input wire reset,
    input wire sampling_clock,
    output wire dma_done,
    output wire [N_TRIGGERS-1:0] triggers,
    axi_lite.slave axi_in,
    AXI.master scope_out,
    axi_stream.slave data_in
);

    wire [7:0] addr_1;
    wire [7:0] addr_2;
    wire [7:0] addr_3;
    wire [7:0] addr_4;
    wire [7:0] addr_5;
    wire [7:0] addr_6;

    axi_lite #(.INTERFACE_NAME("MUX CONTROLLER")) mux_ctrl_axi();
    axi_lite #(.INTERFACE_NAME("TRIGGER CONTROLLER")) uscope_axi();
    axi_lite #(.INTERFACE_NAME("USCOPE TIMEBASE")) timebase_axi();

    axil_crossbar_interface #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(32),
        .NM(1),
        .NS(3),
        .SLAVE_ADDR('{
            BASE_ADDRESS, 
            BASE_ADDRESS + 'h100,
            BASE_ADDRESS + 'h200
        }),
        .SLAVE_MASK('{3{32'h0f00}})
    ) axi_xbar (
        .clock(clock),
        .reset(reset),
        .slaves('{axi_in}),
        .masters('{
            mux_ctrl_axi,
            timebase_axi,
            uscope_axi
        })
    );


    reg [31:0] cu_write_registers [6:0];
    reg [31:0] cu_read_registers [6:0];
    localparam [31:0] VARIABLE_INITIAL_VALUES [6:0] = '{7{1'b0}};

    axil_simple_register_cu #(
        .N_READ_REGISTERS(7),
        .N_WRITE_REGISTERS(7),
        .INITIAL_OUTPUT_VALUES(VARIABLE_INITIAL_VALUES),
        .REGISTERS_WIDTH(32),
        .ADDRESS_MASK('hff)
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(cu_read_registers),
        .output_registers(cu_write_registers),
        .axil(mux_ctrl_axi)
    );

    wire external_capture_enable;
    assign external_capture_enable = cu_write_registers[0][24];
    assign addr_1 = cu_write_registers[1];
    assign addr_2 = cu_write_registers[2];
    assign addr_3 = cu_write_registers[3];
    assign addr_4 = cu_write_registers[4];
    assign addr_5 = cu_write_registers[5];
    assign addr_6 = cu_write_registers[6];
    

    assign cu_read_registers = cu_write_registers;


    axi_stream scope_in[8]();

    axi_stream_extractor #(
        .DATA_WIDTH(DATA_WIDTH),
        .REGISTERED(0)
    ) extractor_0(
        .clock(clock),
        .selector(addr_1),
        .out_dest(0),
        .stream_in(data_in),
        .stream_out(scope_in[0])
    );

    axi_stream_extractor #(
        .DATA_WIDTH(DATA_WIDTH),
        .REGISTERED(0)
    ) extractor_1(
        .clock(clock),
        .selector(addr_2),
        .out_dest(1),
        .stream_in(data_in),
        .stream_out(scope_in[1])
    );

    axi_stream_extractor #(
        .DATA_WIDTH(DATA_WIDTH),
        .REGISTERED(0)
    ) extractor_2(
        .clock(clock),
        .selector(addr_3),
        .out_dest(2),
        .stream_in(data_in),
        .stream_out(scope_in[2])
    );

    axi_stream_extractor #(
        .DATA_WIDTH(DATA_WIDTH),
        .REGISTERED(0)
    ) extractor_3(
        .clock(clock),
        .selector(addr_4),
        .out_dest(3),
        .stream_in(data_in),
        .stream_out(scope_in[3])
    );

    axi_stream_extractor #(
        .DATA_WIDTH(DATA_WIDTH),
        .REGISTERED(0)
    ) extractor_4(
        .clock(clock),
        .selector(addr_5),
        .out_dest(4),
        .stream_in(data_in),
        .stream_out(scope_in[4])
    );

    axi_stream_extractor #(
        .DATA_WIDTH(DATA_WIDTH),
        .REGISTERED(0)
    ) extractor_5(
        .clock(clock),
        .selector(addr_6),
        .out_dest(5),
        .stream_in(data_in),
        .stream_out(scope_in[5])
    );

    wire sample_scope;

    enable_generator #(
        .COUNTER_WIDTH(24),
        .EXTERNAL_TIMEBASE_ENABLE(1)
    ) scope_tb(
        .clock(clock),
        .reset(reset),
        .ext_timebase(sampling_clock),
        .gen_enable_in(0),
        .enable_out(sample_scope),
        .axil(timebase_axi)
    );

    axi_stream scope_in_sync[8]();
    generate
        genvar i;
        for(i = 0; i<8; i++)begin
            axis_sync_repeater ch_synchronizer (
                .clock(clock),
                .reset(reset),
                .sync(sample_scope),
                .in(scope_in[i]),
                .out(scope_in_sync[i])
            );    
        end
    endgenerate
    

    uScope_dma #(
        .N_TRIGGERS(2),
        .DATA_WIDTH(DATA_WIDTH),
        .DEST_WIDTH(DEST_WIDTH),
        .N_STREAMS(8),
        .MAX_TRANSFER_SIZE(MAX_TRANSFER_SIZE)
    )scope_internal (
        .clock(clock),
        .reset(reset),
        .trigger_out(triggers),
        .stream_in(scope_in_sync),
        .out(scope_out),
        .axi_in(uscope_axi),
        .dma_done(dma_done)
    );


    assign data_in.ready = scope_in_sync[0].ready & scope_in_sync[1].ready & scope_in_sync[2].ready & scope_in_sync[3].ready & scope_in_sync[4].ready & scope_in_sync[5].ready;

endmodule
/**
    {
        "name": "uScope_stream",
        "type": "peripheral",
        "registers":[
            {
                "name": "scope_control",
                "offset": "0x0",
                "description": "uScope sampling control",
                "direction": "RW",
                "fields":[
                    {
                        "name":"external_capture",
                        "description": "Enable external caputure",
                        "start_position": 24,
                        "length": 1
                    }
                ]
            },
            {
                "name": "addr_1",
                "offset": "0x4",
                "description": "Address for channel 1 mux",
                "direction": "RW"
            },
            {
                "name": "addr_2",
                "offset": "0x8",
                "description": "Address for channel 2 mux",
                "direction": "RW"
            },
            {
                "name": "addr_3",
                "offset": "0xC",
                "description": "Address for channel 3 mux",
                "direction": "RW"
            },
            {
                "name": "addr_4",
                "offset": "0x10",
                "description": "Address for channel 4 mux",
                "direction": "RW"
            },
            {
                "name": "addr_5",
                "offset": "0x14",
                "description": "Address for channel 5 mux",
                "direction": "RW"
            },
            {
                "name": "addr_6",
                "offset": "0x18",
                "description": "Address for channel 6 mux",
                "direction": "RW"
            }
        ]
    }
**/