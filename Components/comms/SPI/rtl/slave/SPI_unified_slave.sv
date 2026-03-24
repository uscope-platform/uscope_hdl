// Copyright 2026 Filippo Savi
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

module SPI_unified_slave#(
    N_CHANNELS=3,
    REGISTERS_WIDTH=16,
    DEFAULT_LENGTH = 16,
    DEFAULT_CONFIG = 0
)(
    input wire clock,
    input wire reset,
    input wire enable,
    output reg [N_CHANNELS-1:0] MISO,
    input wire SCLK,
    input wire [N_CHANNELS-1:0] MOSI,
    input wire [N_CHANNELS-1:0] SS,
    output wire slave_clock,
    axi_lite.slave axi_in,
    axi_stream.slave spi_data_in,
    axi_stream.master spi_data_out
);

    axi_stream parallel_in[N_CHANNELS]();
    axi_stream parallel_out[N_CHANNELS]();
    genvar i;
    generate
        for (i = 0; i < N_CHANNELS; i++) begin
            always_ff @(posedge clock)begin
                if (spi_data_in.valid && (spi_data_in.dest == i)) begin
                    parallel_in[i].data  <= spi_data_in.data;
                    parallel_in[i].valid <= 1'b1;
                end else begin
                    parallel_in[i].valid <= 1'b0;
                end
            end
        end
    endgenerate


    SPI_slave #(
        .N_CHANNELS(N_CHANNELS),
        .REGISTERS_WIDTH(REGISTERS_WIDTH),
        .OUTPUT_WIDTH(spi_data_out.DATA_WIDTH),
        .DEFAULT_LENGTH(DEFAULT_LENGTH),
        .DEFAULT_CONFIG(DEFAULT_CONFIG)
    ) spi_interface (
        .clock(clock),
        .reset(reset),
        .enable(enable),
        .MISO(MISO),
        .SCLK(SCLK),
        .MOSI(MOSI),
        .SS(SS),
        .slave_clock(slave_clock),
        .axi_in(axi_in),
        .spi_data_in(parallel_in),
        .spi_data_out(parallel_out)
    );



    axi_stream_combiner #(
        .INPUT_DATA_WIDTH(spi_data_out.DATA_WIDTH),
        .OUTPUT_DATA_WIDTH(spi_data_out.DATA_WIDTH),
        .DEST_WIDTH(spi_data_out.DEST_WIDTH),
        .USER_WIDTH(spi_data_out.USER_WIDTH),
        .N_STREAMS(N_CHANNELS),
        .BUFFER_DEPTH(16)
    )combiner(
        .clock(clock),
        .reset(reset),
        .stream_in(parallel_out),
        .stream_out(spi_data_out)
    );



endmodule
