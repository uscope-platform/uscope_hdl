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
`timescale 10 ns / 1 ns
`include "interfaces.svh"

module fcore_complex #(
    parameter PRAGMA_MKFG_MODULE_TOP = "fCore",
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
    parameter EFI_IMPLEMENTED = 0,
    parameter CONDITIONAL_SELECT_IMPLEMENTED = 1,
    parameter FULL_COMPARE = 1,
    parameter TRANSLATION_TABLE_INIT = "TRANSPARENT",
    parameter MAX_CHANNELS = 4,
    parameter MOVER_ADDRESS_WIDTH = 32,
    parameter MOVER_CHANNEL_NUMBER=1,
    parameter [MOVER_ADDRESS_WIDTH-1:0] MOVER_SOURCE_ADDR [MOVER_CHANNEL_NUMBER-1:0] = '{MOVER_CHANNEL_NUMBER{{MOVER_ADDRESS_WIDTH{1'b0}}}},
    parameter [MOVER_ADDRESS_WIDTH-1:0] MOVER_TARGET_ADDR [MOVER_CHANNEL_NUMBER-1:0] = '{MOVER_CHANNEL_NUMBER{{MOVER_ADDRESS_WIDTH{1'b0}}}},
    parameter PRAGMA_MKFG_DATAPOINT_NAMES = "" 
)(
    input wire core_clock,
    input wire interface_clock,
    input wire core_reset,
    input wire interface_reset,
    input wire start,
    output reg done,
    output wire efi_start,
    axi_stream.master efi_arguments,
    axi_stream.slave efi_results,
    axi_lite.slave control_axi,
    AXI.slave fcore_rom,
    axi_stream.slave core_dma_in,
    axi_stream.master core_dma_out
);

    axi_stream axis_dma_read_req();
    axi_stream axis_dma_read_resp();

    fCore #(
        .PRAGMA_MKFG_MODULE_TOP(PRAGMA_MKFG_MODULE_TOP),
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
        .MAX_CHANNELS(MAX_CHANNELS)
    )  core (
        .clock(core_clock),
        .axi_clock(interface_clock),
        .reset(core_reset),
        .reset_axi(interface_reset),
        .run(start),
        .done(done),
        .axis_dma_write(core_dma_in),
        .axis_dma_read_request(axis_dma_read_req),
        .axis_dma_read_response(axis_dma_read_resp),
        .efi_start(efi_start),
        .efi_arguments(efi_arguments),
        .efi_results(efi_results),
        .control_axi_in(control_axi),
        .axi(fcore_rom)
    );
    

    axis_data_mover #(
        .DATA_WIDTH(32),
        .ADDRESS_WIDTH(MOVER_ADDRESS_WIDTH),
        .CHANNEL_NUMBER(MOVER_CHANNEL_NUMBER),
        .SOURCE_ADDR(MOVER_SOURCE_ADDR),
        .TARGET_ADDR(MOVER_TARGET_ADDR),
        .PRAGMA_MKFG_DATAPOINT_NAMES(PRAGMA_MKFG_DATAPOINT_NAMES)
    ) dma (
        .clock(core_clock),
        .reset(core_reset),
        .start(done),
        .data_request(axis_dma_read_req),
        .data_response(axis_dma_read_resp),
        .data_out(core_dma_out)
    );



endmodule