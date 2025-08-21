// Copyright 2023 Filippo Savi
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
`timescale 10 ns / 1 ns
`include "interfaces.svh"

module fcore_complex #(
    parameter PRAGMA_MKFG_CHILD_PREFIX = "complex",
    parameter SIM_CONFIG = "FALSE",
    parameter FAST_DEBUG = "TRUE",
    parameter INIT_FILE = "init.mem",
    parameter TRANSLATION_TABLE_INIT_FILE = "",
    parameter DMA_BASE_ADDRESS = 32'h43c00000,
    parameter INSTRUCTION_STORE_SIZE = 4096,
    parameter INSTRUCTION_WIDTH = 32,
    parameter DATAPATH_WIDTH = 32,
    parameter OPCODE_WIDTH = 5,
    parameter REGISTER_FILE_DEPTH = 64,
    parameter RECIPROCAL_PRESENT = 0,
    parameter BITMANIP_IMPLEMENTED = 0,
    parameter LOGIC_IMPLEMENTED = 1,
    parameter EFI_IMPLEMENTED = 1,
    parameter CONDITIONAL_SELECT_IMPLEMENTED = 1,
    parameter FULL_COMPARE = 0,
    parameter TRANSLATION_TABLE_INIT = "TRANSPARENT",
    parameter MAX_CHANNELS = 4,
    parameter MOVER_ADDRESS_WIDTH = 32,
    parameter MOVER_CHANNEL_NUMBER=1,
    parameter PRAGMA_MKFG_DATAPOINT_NAMES = "",
    parameter [31:0] MKFG_DESTINATIONS [MOVER_CHANNEL_NUMBER-1:0] = '{default:0},
    parameter EFI_TYPE = "NONE",
    parameter AXI_ADDR_WIDTH = 32,
    parameter N_CONSTANTS = 3,
    parameter REPEAT_MODE = 0,
    parameter MULTICHANNEL_MODE = 0,
    parameter RAW_AXI_ACCESS = 0
)(
    input wire core_clock,
    input wire interface_clock,
    input wire core_reset,
    input wire interface_reset,
    input wire start,
    input wire repeat_outputs,
    output reg done,
    axi_lite.slave control_axi,
    AXI.slave fcore_rom,
    axi_stream.slave core_dma_in,
    axi_stream.master core_dma_out
);

    start_request_pulse: assert property(@(posedge core_clock) start |=> !start) else begin
        $display("-----------------------------------------------------------------");
        $display("ERROR: The start signal must be asserted only for a single clock cycle.");
        $display("-----------------------------------------------------------------");
        $fatal();
    end


    done_flag_pulse: assert property(@(posedge core_clock) done |=> !done) else begin
        $display("-----------------------------------------------------------------");
        $display("ERROR: Done signal must be asserted only for a single clock cycle.");
        $display("-----------------------------------------------------------------");
        $fatal();
    end


    no_start_before_done: assert property(@(posedge core_clock) start |=> !start[*1:$] intersect done[->1]) else begin
        $display("-----------------------------------------------------------------");
        $display("ERROR: The start signal must not be asserted before the done signal is high.");
        $display("-----------------------------------------------------------------");
        $fatal();
    end


    axi_stream efi_arguments();
    axi_stream efi_results();

    axi_stream axis_dma_read_req();
    axi_stream axis_dma_read_resp();

    wire core_done;

    generate
        if(EFI_TYPE == "NONE")begin
        end else if(EFI_TYPE == "TRIG") begin

            efi_trig efi_trig_unit(
                .clock(core_clock),
                .reset(core_reset),
                .efi_arguments(efi_arguments),
                .efi_results(efi_results)
            );
        end else if(EFI_TYPE == "SORT") begin

            efi_sorter #(
                .MAX_SORT_LENGTH(256)
            )efi_sort_unit(
                .clock(core_clock),
                .reset(core_reset),
                .efi_arguments(efi_arguments),
                .efi_results(efi_results)
            );

        end else if(EFI_TYPE == "RECIPROCAL") begin


            efi_reciprocal reciprocal_unit(
                .clock(core_clock),
                .reset(core_reset),
                .efi_arguments(efi_arguments),
                .efi_results(efi_results)
            );

        end else begin
            $error("%m UNSUPPORTED EFI TYPE IN CORE COMPLEX");
        end
    endgenerate

    axi_lite #(.ADDR_WIDTH(AXI_ADDR_WIDTH)) fcore_axi();
    axi_lite #(.ADDR_WIDTH(AXI_ADDR_WIDTH)) dma_axi();
    axi_lite #(.ADDR_WIDTH(AXI_ADDR_WIDTH)) constants_axi();

    axi_stream constants_out();

    wire [$clog2(MAX_CHANNELS)-1:0] n_channels;

    localparam [AXI_ADDR_WIDTH-1:0] AXI_ADDRESSES [2:0] = '{
        DMA_BASE_ADDRESS + 'h2000,
        DMA_BASE_ADDRESS + 'h1000,
        DMA_BASE_ADDRESS
        };
    
    axil_crossbar_interface #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(AXI_ADDR_WIDTH),
        .NM(1),
        .NS(3),
        .SLAVE_ADDR(AXI_ADDRESSES),
        .SLAVE_MASK('{3{32'hf000}})
    ) control_interconnect (
        .clock(core_clock),
        .reset(core_reset),
        .slaves('{control_axi}),
        .masters({constants_axi, dma_axi, fcore_axi})
    );

    genvar n;        

    wire [7:0] n_active_constants;

    multichannel_constant #(
        .CONSTANT_WIDTH(32),
        .N_CHANNELS(MAX_CHANNELS),
        .N_CONSTANTS(N_CONSTANTS)
    )constants(
        .clock(core_clock),
        .reset(core_reset),
        .sync(start),
        .n_active_constants(n_active_constants),
        .const_out(constants_out),
        .axil(constants_axi)
    );

    axi_stream merged_out();

    axi_stream_combiner #(
        .INPUT_DATA_WIDTH(32),
        .OUTPUT_DATA_WIDTH(32),
        .DEST_WIDTH(32),
        .USER_WIDTH(32),
        .N_STREAMS(2)
    )constants_combiner(
        .clock(core_clock),
        .reset(core_reset),
        .stream_in('{constants_out, core_dma_in}),
        .stream_out(merged_out)
    );
    
    reg [7:0] start_delay = 0;
    reg start_core = 0;
    
    always_ff @(posedge core_clock) begin
        start_core <= 0;

        if(n_active_constants == 0 && start) start_core <= 1;

        if(start_delay == MAX_CHANNELS-1)begin
            start_delay <= 0;
            start_core <= 1;
        end else begin
            if(constants_out.tlast) begin
                start_delay <= 1;
            end else if (start_delay>0)begin
                start_delay <= start_delay + 1;
            end
        end
        
    end

    fCore #(
        .PRAGMA_MKFG_MODULE_TOP("core"),
        .SIM_CONFIG(SIM_CONFIG),
        .FAST_DEBUG(FAST_DEBUG),
        .INIT_FILE(INIT_FILE),
        .TRANSLATION_TABLE_INIT_FILE(TRANSLATION_TABLE_INIT_FILE),
        .DMA_BASE_ADDRESS(DMA_BASE_ADDRESS),
        .INSTRUCTION_STORE_SIZE(INSTRUCTION_STORE_SIZE),
        .INSTRUCTION_WIDTH(INSTRUCTION_WIDTH),
        .DATAPATH_WIDTH(DATAPATH_WIDTH),
        .OPCODE_WIDTH(OPCODE_WIDTH),
        .REGISTER_FILE_DEPTH(REGISTER_FILE_DEPTH),
        .RECIPROCAL_PRESENT(RECIPROCAL_PRESENT),
        .BITMANIP_IMPLEMENTED(BITMANIP_IMPLEMENTED),
        .LOGIC_IMPLEMENTED(LOGIC_IMPLEMENTED),
        .EFI_IMPLEMENTED(EFI_IMPLEMENTED),
        .CONDITIONAL_SELECT_IMPLEMENTED(CONDITIONAL_SELECT_IMPLEMENTED),
        .FULL_COMPARE(FULL_COMPARE),
        .TRANSLATION_TABLE_INIT(TRANSLATION_TABLE_INIT),
        .MAX_CHANNELS(MAX_CHANNELS),
        .RAW_AXI_ACCESS(RAW_AXI_ACCESS)
    )  core (
        .clock(core_clock),
        .axi_clock(interface_clock),
        .reset(core_reset),
        .reset_axi(interface_reset),
        .run(start_core),
        .done(core_done),
        .n_channels(n_channels),
        .axis_dma_write(merged_out),
        .axis_dma_read_request(axis_dma_read_req),
        .axis_dma_read_response(axis_dma_read_resp),
        .efi_arguments(efi_arguments),
        .efi_results(efi_results),
        .control_axi_in(fcore_axi),
        .axi(fcore_rom)
    );


    axis_dynamic_data_mover #(
        .DATA_WIDTH(32),
        .MAX_CHANNELS(MOVER_CHANNEL_NUMBER),
        .PRAGMA_MKFG_DATAPOINT_NAMES(PRAGMA_MKFG_DATAPOINT_NAMES),
        .MKFG_DESTINATIONS(MKFG_DESTINATIONS),
        .REPEAT_MODE(REPEAT_MODE),
        .MULTICHANNEL_MODE(MULTICHANNEL_MODE)
    )dma (
        .clock(core_clock),
        .reset(core_reset),
        .start(core_done),
        .repeat_outputs(repeat_outputs),
        .data_request(axis_dma_read_req),
        .data_response(axis_dma_read_resp),
        .data_out(core_dma_out),
        .axi_in(dma_axi),
        .done(done)
    );


endmodule