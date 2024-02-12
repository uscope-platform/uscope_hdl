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
    parameter EFI_IMPLEMENTED = 1,
    parameter CONDITIONAL_SELECT_IMPLEMENTED = 1,
    parameter FULL_COMPARE = 0,
    parameter TRANSLATION_TABLE_INIT = "TRANSPARENT",
    parameter MAX_CHANNELS = 4,
    parameter MOVER_ADDRESS_WIDTH = 32,
    parameter MOVER_CHANNEL_NUMBER=1,
    parameter [MOVER_ADDRESS_WIDTH-1:0] MOVER_SOURCE_ADDR [MOVER_CHANNEL_NUMBER-1:0] = '{MOVER_CHANNEL_NUMBER{{MOVER_ADDRESS_WIDTH{1'b0}}}},
    parameter [MOVER_ADDRESS_WIDTH-1:0] MOVER_TARGET_ADDR [MOVER_CHANNEL_NUMBER-1:0] = '{MOVER_CHANNEL_NUMBER{{MOVER_ADDRESS_WIDTH{1'b0}}}},
    parameter PRAGMA_MKFG_DATAPOINT_NAMES = "",
    parameter EFI_TYPE = "NONE",
    parameter AXI_ADDR_WIDTH = 32,
    parameter N_CONSTANTS = 3
)(
    input wire core_clock,
    input wire interface_clock,
    input wire core_reset,
    input wire interface_reset,
    input wire start,
    output reg done,
    input wire constant_trigger,
    axi_lite.slave control_axi,
    AXI.slave fcore_rom,
    axi_stream.slave core_dma_in,
    axi_stream.master core_dma_out
);

    axi_stream efi_arguments();
    axi_stream efi_results();

    axi_stream axis_dma_read_req();
    axi_stream axis_dma_read_resp();

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

        end else begin
            $error("%m UNSUPPORTED EFI TYPE IN CORE COMPLEX");
        end
    endgenerate

    axi_lite #(.ADDR_WIDTH(AXI_ADDR_WIDTH)) fcore_axi();
    axi_lite #(.ADDR_WIDTH(AXI_ADDR_WIDTH)) dma_axi();
    axi_lite #(.ADDR_WIDTH(AXI_ADDR_WIDTH)) constant_axi[N_CONSTANTS]();

    axi_stream constant_out[N_CONSTANTS]();
    axi_stream repeated_constant[N_CONSTANTS]();


    localparam N_AXI_SLAVES = 2 + N_CONSTANTS;

    localparam [AXI_ADDR_WIDTH-1:0] AXI_ADDRESSES [N_AXI_SLAVES-1:0] = '{
        DMA_BASE_ADDRESS + 'h2000,
        DMA_BASE_ADDRESS + 'h3000,
        DMA_BASE_ADDRESS + 'h4000,
        DMA_BASE_ADDRESS + 'h1000,
        DMA_BASE_ADDRESS
        };
    
    axil_crossbar_interface #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(AXI_ADDR_WIDTH),
        .NM(1),
        .NS(N_AXI_SLAVES),
        .SLAVE_ADDR(AXI_ADDRESSES),
        .SLAVE_MASK('{N_AXI_SLAVES{32'hf000}})
    ) control_interconnect (
        .clock(core_clock),
        .reset(core_reset),
        .slaves('{control_axi}),
        .masters({constant_axi, dma_axi, fcore_axi})
    );

    genvar n;
    
    for(n = 0; n<N_CONSTANTS; n=n+1)begin
        axis_constant constant (
            .clock(core_clock),
            .reset(core_reset),
            .sync(1),
            .const_out(constant_out[n]),
            .axil(constant_axi[n])
        );

        axis_sync_repeater #(
            .HOLD_VALID(1)
        ) repeater(
            .clock(core_clock),
            .reset(core_reset),
            .sync(start),
            .in(constant_out[n]),
            .out(repeated_constant[n])
        );
    end
        
    axi_stream merged_out();

    axi_stream_combiner #(
        .INPUT_DATA_WIDTH(32),
        .OUTPUT_DATA_WIDTH(32),
        .N_STREAMS(N_CONSTANTS+1)
    )constants_combiner(
        .clock(core_clock),
        .reset(core_reset),
        .stream_in('{repeated_constant, core_dma_in}),
        .stream_out(merged_out)
    );

    enum reg [1:0] {
        wait_constants = 0,
        idle = 1, 
        wait_input_transfer_start = 2,
        wait_input_transfer_end = 3 
    } input_fsm = wait_constants;

    wire core_done;
    
    reg start_core;

    always_ff @(posedge core_clock)begin
        case (input_fsm)
            wait_constants:begin
                start_core <= start;
                if(constant_out[0].valid | constant_out[1].valid | constant_out[2].valid)begin
                    input_fsm <= idle;
                end
            end
            idle: begin
                start_core <= 0;
                if(start)begin
                    input_fsm <= wait_input_transfer_start;
                end
            end
            wait_input_transfer_start: begin
                if(merged_out.valid == 1)begin
                    input_fsm <= wait_input_transfer_end;
                end
            end
            wait_input_transfer_end: begin
                 if(merged_out.valid == 0)begin
                    start_core <= 1;
                    input_fsm <= idle;
                end
            end
        endcase
    end


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
        .run(start_core),
        .done(core_done),
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
        .PRAGMA_MKFG_DATAPOINT_NAMES(PRAGMA_MKFG_DATAPOINT_NAMES) 
    )dma (
        .clock(core_clock),
        .reset(core_reset),
        .start(core_done),
        .data_request(axis_dma_read_req),
        .data_response(axis_dma_read_resp),
        .data_out(core_dma_out),
        .axi_in(dma_axi),
        .done(done)
    );
    
endmodule