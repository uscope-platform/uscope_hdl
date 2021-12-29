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


module fCore_dma_endpoint #(parameter BASE_ADDRESS = 32'h43c00000, DATAPATH_WIDTH = 20 ,PULSE_STRETCH_LENGTH = 6, REG_ADDR_WIDTH = 8, LEGACY_READ=1)(
    input wire clock,
    input wire reset,
    axi_lite.slave axi_in,
    output reg [REG_ADDR_WIDTH-1:0] dma_write_addr,
    output reg [DATAPATH_WIDTH-1:0] dma_write_data,
    output reg dma_write_valid,
    output reg [REG_ADDR_WIDTH:0] dma_read_addr,
    input wire [DATAPATH_WIDTH-1:0] dma_read_data,
    output reg [REG_ADDR_WIDTH-1:0] n_channels,
    axi_stream.slave axis_dma
    );

    
    axi_stream read_addr();
    axi_stream read_data();
    axi_stream write_data();

    axil_external_registers_cu #(
        .BASE_ADDRESS(BASE_ADDRESS)
    ) AXI_endpoint (
        .clock(clock),
        .reset(reset),
        .read_address(read_addr),
        .read_data(read_data),
        .write_data(write_data),
        .axi_in(axi_in)
    );

    assign write_data.ready = 1;

    always_ff @(posedge clock) begin
        dma_write_valid <= 0;
        dma_write_addr <= 0;
        dma_write_data <= 0;
        if(axis_dma.valid)begin
            dma_write_addr <= axis_dma.dest;
            dma_write_data <= axis_dma.data;
            dma_write_valid <= 1;
            n_channels <= 1;
        end else if(write_data.valid)begin
            if(write_data.dest == 0) begin
                n_channels <= write_data.data;
            end else begin
                dma_write_addr <= write_data.dest;
                dma_write_data <= write_data.data;
                dma_write_valid <= 1;    
            end
            
        end
    end

    reg read_result_ready;

    always_ff @(posedge clock) begin
        if(!reset)begin
            read_addr.ready <= 1;
            dma_read_addr <= 0;
            read_result_ready <= 0;
            read_data.data <= 0;
        end else begin
            read_data.valid <= 0;

            if(read_addr.valid) begin
                if(read_addr.data == 0) begin
                    read_data.data <= n_channels;
                    read_data.valid <= 1;
                end else begin
                    dma_read_addr <= read_addr.data;
                    read_result_ready <= 1;    
                end
                
            end
            if(read_result_ready)begin
                read_data.valid <= 1;
                read_data.data <= dma_read_data;
                read_result_ready <= 0;
            end
        end
    end



endmodule
 