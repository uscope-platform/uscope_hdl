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
module fCore_Istore # (
        parameter integer DATA_WIDTH = 32,
        parameter integer MEM_DEPTH = 4096,
        parameter ADDR_WIDTH = $clog2(MEM_DEPTH),
        parameter FAST_DEBUG = "TRUE",
        parameter INIT_FILE = "init.mem"
    )(
        input wire clock_in,
        input wire clock_out,
        input wire reset_in,
        input wire reset_out,
        input wire enable_bus_read,
        input wire [ADDR_WIDTH-1:0] dma_read_addr,
        output reg [2*DATA_WIDTH-1:0] dma_read_data_w,
        axi_stream.master iommu_control,
        AXI.slave axi
    );
    
    localparam [DATA_WIDTH-1:0] SECTION_SEPARATOR = {{(DATA_WIDTH-8){1'b0}}, {8'hc}};
  
    wire [DATA_WIDTH-1:0] write_data;
    wire [2*DATA_WIDTH-1:0] read_data;
    wire [ADDR_WIDTH-1:0] write_address;
    wire [ADDR_WIDTH-1:0] read_address;
    wire write_enable;

    istore_axi_if #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    )axi_if(
        .clock_in(clock_in),
        .reset_in(reset_in),
        .write_data(write_data),
        .read_data(read_data),
        .write_address(write_address),
        .read_address(read_address),
        .write_enable(write_enable),
        .axi(axi)
    );

    assign dma_read_data_w = read_data;

    wire [ADDR_WIDTH-1:0] core_read_address;
    assign core_read_address = header_counter + dma_read_addr;

    istore_memory #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .INIT_FILE(INIT_FILE),
        .FAST_DEBUG(FAST_DEBUG)
    ) memory_block(
        .clock_in(clock_in),
        .clock_out(clock_out),
        .reset(reset_in),
        .data_a(write_data),
        .data_b(read_data),
        .addr_a(write_address),
        .addr_b( enable_bus_read ? write_address : core_read_address),
        .we_a(write_enable)
    );

    reg [31:0] header_counter = 0;

    enum reg [2:0] {
        metadata_section = 0,
        io_map_section = 1, 
        program_section = 2
    } write_watcher = metadata_section;

    always_ff@(posedge clock_in)begin
        iommu_control.valid <= 0;
        if(write_enable)begin
            case (write_watcher)
            metadata_section:begin
                if(write_data == SECTION_SEPARATOR)begin
                    write_watcher <= io_map_section;
                end
                if(write_data != 0)begin
                    header_counter++;
                end
            end
            io_map_section:begin
                if(write_data == SECTION_SEPARATOR)begin
                    write_watcher <= program_section;
                end else begin
                    iommu_control.data <= write_data;
                    iommu_control.valid <= 1;
                end
                header_counter++;
            end
            program_section: begin
                if(write_data == SECTION_SEPARATOR)begin
                    write_watcher <= metadata_section;
                end
            end
        endcase
        end
        
    end


    endmodule
