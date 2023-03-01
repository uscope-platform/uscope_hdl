// Copyright 2021 Filippo Savi
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
    BASE_ADDRESS = 0
) (
    input wire clock,
    input wire reset,
    input wire sampling_clock,
    input wire dma_done,
    output wire [N_TRIGGERS-1:0] triggers,
    axi_lite.slave axi_in,
    axi_stream.master scope_out,
    axi_stream.slave data_in,
    axi_lite.master dma_axi
);

    reg[7:0] addr_1;
    reg[7:0] addr_2;
    reg[7:0] addr_3;
    reg[7:0] addr_4;
    reg[7:0] addr_5;
    reg[7:0] addr_6;

    axi_lite #(.INTERFACE_NAME("MUX CONTROLLER")) mux_ctrl_axi();
    axi_lite #(.INTERFACE_NAME("TRIGGER CONTROLLER")) uscope_axi();
    axi_lite #(.INTERFACE_NAME("USCOPE TIMEBASE")) timebase_axi();

    axil_crossbar_interface #(
        .DATA_WIDTH(32),
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


    wire[31:0] int_readdata;
    wire [31:0] scope_window_base;

    reg [31:0] cu_write_registers [1:0];
    reg [31:0] cu_read_registers [1:0];

    axil_simple_register_cu #(
        .N_READ_REGISTERS(2),
        .N_WRITE_REGISTERS(2),
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
    assign addr_1 = cu_write_registers[0][2:0];
    assign addr_2 = cu_write_registers[0][6:4];
    assign addr_3 = cu_write_registers[0][10:8];
    assign addr_4 = cu_write_registers[0][14:12];
    assign addr_5 = cu_write_registers[0][18:16];
    assign addr_6 = cu_write_registers[0][22:20];
    assign scope_window_base = cu_write_registers[1];
    assign external_capture_enable = cu_write_registers[0][24];


    assign cu_read_registers[0][2:0] = addr_1;
    assign cu_read_registers[0][3] = 0;
    assign cu_read_registers[0][6:4] = addr_2;
    assign cu_read_registers[0][7] = 0;
    assign cu_read_registers[0][10:8] = addr_3;
    assign cu_read_registers[0][11] = 0;
    assign cu_read_registers[0][14:12] = addr_4;
    assign cu_read_registers[0][15] = 0;
    assign cu_read_registers[0][18:16] = addr_5;
    assign cu_read_registers[0][19] = 0;
    assign cu_read_registers[0][22:20] = addr_6;
    assign cu_read_registers[0][23] = 0;
    assign cu_read_registers[0][24] = external_capture_enable;
    assign cu_read_registers[0][31:25] = 0;
    assign cu_read_registers[1] = scope_window_base;


    reg [7:0] selector_1;
    reg [7:0] selector_2;
    reg [7:0] selector_3;
    reg [7:0] selector_4;
    reg [7:0] selector_5;
    reg [7:0] selector_6;

    always_ff @(posedge clock) begin
        selector_1 <= scope_window_base + addr_1;
        selector_2 <= scope_window_base + addr_2;
        selector_3 <= scope_window_base + addr_3;
        selector_4 <= scope_window_base + addr_4;
        selector_5 <= scope_window_base + addr_5;
        selector_6 <= scope_window_base + addr_6;
    end



    axi_stream scope_in[8]();

    axi_stream_extractor #(
        .DATA_WIDTH(24),
        .REGISTERED(0)
    ) extractor_0(
        .clock(clock),
        .selector(selector_1),
        .out_dest(0),
        .stream_in(data_in),
        .stream_out(scope_in[0])
    );

    axi_stream_extractor #(
        .DATA_WIDTH(24),
        .REGISTERED(0)
    ) extractor_1(
        .clock(clock),
        .selector(selector_2),
        .out_dest(1),
        .stream_in(data_in),
        .stream_out(scope_in[1])
    );

    axi_stream_extractor #(
        .DATA_WIDTH(24),
        .REGISTERED(0)
    ) extractor_2(
        .clock(clock),
        .selector(selector_3),
        .out_dest(2),
        .stream_in(data_in),
        .stream_out(scope_in[2])
    );

    axi_stream_extractor #(
        .DATA_WIDTH(24),
        .REGISTERED(0)
    ) extractor_3(
        .clock(clock),
        .selector(selector_4),
        .out_dest(3),
        .stream_in(data_in),
        .stream_out(scope_in[3])
    );

    axi_stream_extractor #(
        .DATA_WIDTH(24),
        .REGISTERED(0)
    ) extractor_4(
        .clock(clock),
        .selector(selector_5),
        .out_dest(4),
        .stream_in(data_in),
        .stream_out(scope_in[4])
    );

    axi_stream_extractor #(
        .DATA_WIDTH(24),
        .REGISTERED(0)
    ) extractor_5(
        .clock(clock),
        .selector(selector_6),
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
    

    uScope #(
        .N_TRIGGERS(2),
        .DATA_WIDTH(24)
    ) scope (
        .clock(clock),
        .reset(reset),
        .dma_done(dma_done),
        .in_1(scope_in_sync[0]),
        .in_2(scope_in_sync[1]),
        .in_3(scope_in_sync[2]),
        .in_4(scope_in_sync[3]),
        .in_5(scope_in_sync[4]),
        .in_6(scope_in_sync[5]),
        .in_7(scope_in_sync[6]),
        .in_8(scope_in_sync[7]),
        .trigger_out(triggers),
        .dma_axi(dma_axi),
        .out(scope_out),
        .axi_in(uscope_axi)
    );

    assign data_in.ready = scope_in_sync[0].ready & scope_in_sync[1].ready & scope_in_sync[2].ready & scope_in_sync[3].ready & scope_in_sync[4].ready & scope_in_sync[5].ready;

endmodule