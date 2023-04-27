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


`timescale 1 ns / 100 ps
`include "interfaces.svh"

module axil_dma #(
    parameter MAX_TRANSFER_SIZE = 65536
)(
    input wire clock,
    input wire reset,
    input wire enable,
    axi_lite.slave axi_in,
    axi_stream.slave data_in,
    axi_lite.master axi_out
);


    reg [31:0] cu_write_registers [2:0];
    reg [31:0] cu_read_registers [2:0];
  
    axil_simple_register_cu #(
        .N_READ_REGISTERS(3),
        .N_WRITE_REGISTERS(3),
        .REGISTERS_WIDTH(32),
        .ADDRESS_MASK('hff),
        .INITIAL_OUTPUT_VALUES('{3{'h0}})
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(cu_read_registers),
        .output_registers(cu_write_registers),
        .axil(axi_in)
    );

    reg [31:0] target_base;
    reg [31:0] transfer_size;


    assign target_base = cu_write_registers[0];
    assign transfer_size = cu_write_registers[1];

    assign cu_read_registers[0] = target_base;
    assign cu_read_registers[1] = transfer_size;
    assign cu_read_registers[2] = 0;

    reg [$clog2(MAX_TRANSFER_SIZE)-1:0] progress_counter = 0;

    always_ff @(posedge clock) begin
        if(~reset)begin
            axi_out.AWVALID <= 0;
            axi_out.AWPROT <= 0;
            axi_out.WVALID <= 0;
            axi_out.WDATA <= 0;
            axi_out.WSTRB <= 'hF;
            axi_out.AWADDR <= 0;

            axi_out.ARVALID <= 0;
            axi_out.ARADDR <= 0;
            axi_out.ARPROT <= 0;
            axi_out.RREADY <= 1;
            axi_out.BREADY <= 1;
        end else begin
            if(data_in.valid)begin

            end
        end
    end


endmodule
