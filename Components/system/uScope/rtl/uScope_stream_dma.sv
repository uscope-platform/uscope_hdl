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


module uScope_stream_dma #(
    int N_CHANNELS = 6,
    int SCOPE_BASE_ADDRESS = 0,
    int DATA_WIDTH = 32,
    int ADDR_WIDTH = 32,
    int OUTPUT_AXI_WIDTH = 128,
    int DEST_WIDTH = 16,
    int CHANNEL_SAMPLES = 1024,
    int BURST_SIZE = 16
) (
    input wire clock,
    input wire reset,
    input wire sampling_clock,
    output wire dma_done,
    axi_lite.slave axi_in,
    AXI.master scope_out,
    axi_stream.slave data_in
);

    wire [31:0] addr[N_CHANNELS-1:0];

    axi_lite #(.INTERFACE_NAME("MUX CONTROLLER"), .ADDR_WIDTH(ADDR_WIDTH)) mux_ctrl_axi();
    axi_lite #(.INTERFACE_NAME("TRIGGER CONTROLLER"), .ADDR_WIDTH(ADDR_WIDTH)) uscope_axi();
    axi_lite #(.INTERFACE_NAME("USCOPE TIMEBASE"), .ADDR_WIDTH(ADDR_WIDTH)) timebase_axi();

    axil_crossbar_interface #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .NM(1),
        .NS(3),
        .SLAVE_ADDR('{
            SCOPE_BASE_ADDRESS, 
            SCOPE_BASE_ADDRESS + 'h100,
            SCOPE_BASE_ADDRESS + 'h200
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


    reg [31:0] cu_write_registers [N_CHANNELS:0];
    reg [31:0] cu_read_registers [N_CHANNELS:0];
    localparam [31:0] VARIABLE_INITIAL_VALUES [N_CHANNELS:0] = '{(N_CHANNELS+1){1'b0}};

    axil_simple_register_cu #(
        .N_READ_REGISTERS(N_CHANNELS+1),
        .N_WRITE_REGISTERS(N_CHANNELS+1),
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

    wire external_capture_enable, disable_dma;
    assign disable_dma = cu_write_registers[0][0];
    assign external_capture_enable = cu_write_registers[0][24];

    assign cu_read_registers = cu_write_registers;


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

    axi_stream #(.USER_WIDTH(16), .DEST_WIDTH(DEST_WIDTH)) scope_in[N_CHANNELS]();
    axi_stream #(.USER_WIDTH(16), .DEST_WIDTH(DEST_WIDTH)) scope_in_sync[N_CHANNELS]();
    wire [N_CHANNELS-1:0] unrolled_sync_ready;
    assign data_in.ready = &unrolled_sync_ready;

    generate
        genvar i;
        for(i = 0; i<N_CHANNELS; i++)begin
            assign addr[i] = cu_write_registers[i+1];
            assign unrolled_sync_ready[i] = scope_in_sync[i].ready;

            axi_stream_extractor #(
                .DATA_WIDTH(DATA_WIDTH),
                .DEST_WIDTH(32),
                .REGISTERED(0)
            ) extractor (
                .clock(clock),
                .selector(addr[i]),
                .out_dest(i),
                .stream_in(data_in),
                .stream_out(scope_in[i])
            );


            axis_sync_repeater #(
                .HOLD_VALID(1),
                .WAIT_INITIALIZATION(0)
            ) ch_synchronizer (
                .clock(clock),
                .reset(reset),
                .sync(sample_scope),
                .in(scope_in[i]),
                .out(scope_in_sync[i])
            );
        end
    endgenerate


    uScope_dma #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEST_WIDTH(DEST_WIDTH),
        .N_STREAMS(N_CHANNELS),
        .OUTPUT_AXI_WIDTH(OUTPUT_AXI_WIDTH),
        .BURST_SIZE(BURST_SIZE),
        .CHANNEL_SAMPLES(CHANNEL_SAMPLES)
    )scope_internal (
        .clock(clock),
        .reset(reset),
        .disable_dma(disable_dma),
        .stream_in(scope_in_sync),
        .out(scope_out),
        .axi_in(uscope_axi),
        .dma_done(dma_done)
    );


endmodule


/**
    {
        "name": "uScope_stream_dma",
        "type": "parametric_peripheral",
        "registers":[
            {
                "name": "scope_control",
                "n_regs": ["1"],
                "description": "uScope sampling control",
                "direction": "RW",
                "fields":[
                    {
                        "name":"external_capture",
                        "description": "Enable external caputure",
                        "start_position": 24,
                        "n_fields":["1"],
                        "length": 1
                    }, 
                    {
                        "name": "disable_dma",
                        "description": "Disable DMA engine",
                        "start_position": 0,
                        "n_fields":["1"],
                        "length": 1
                    }
                ]
            },
            {
                "name": "addr_$",
                "n_regs": ["N_CHANNELS"],
                "description": "Address for channel $ mux",
                "direction": "RW",
                "fields":[]
            }
        ]
    }
**/