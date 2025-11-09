// Copyright 2025 Filippo Savi
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

module SPI_slave#(
    N_CHANNELS=3,
    REGISTERS_WIDTH=16,
    OUTPUT_WIDTH=32
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
    axi_stream.slave spi_data_in [N_CHANNELS],
    axi_stream.master spi_data_out [N_CHANNELS]
);


    parameter N_REGISTERS = 4;

    reg [31:0] cu_write_registers [N_REGISTERS-1:0];
    reg [31:0] cu_read_registers [N_REGISTERS-1:0];

    axil_simple_register_cu #(
        .N_READ_REGISTERS(N_REGISTERS),
        .N_WRITE_REGISTERS(N_REGISTERS),
        .REGISTERS_WIDTH(32),
        .ADDRESS_MASK('h3f)
    ) axi_if(
        .clock(clock),
        .reset(reset),
        .input_registers(cu_read_registers),
        .output_registers(cu_write_registers),
        .axil(axi_in)
    );

    wire [7:0] transfer_length;
    wire ss_polarity, latching_edge, clock_polarity, msb_first;

    assign clock_polarity = cu_write_registers[0][0];
    assign latching_edge = cu_write_registers[0][1];
    assign ss_polarity = cu_write_registers[0][2];
    assign msb_first = cu_write_registers[0][3];
    assign transfer_length = cu_write_registers[1];


    reg [N_CHANNELS-1:0] s_clks;

    assign slave_clock = ~(|s_clks);

    genvar i;
    generate
        for(i=0; i<N_CHANNELS; i=i+1) begin : gen_spi_slave_registers
            spi_slave_register #(
                .REGISTERS_WIDTH(REGISTERS_WIDTH),
                .OUTPUT_WIDTH(OUTPUT_WIDTH)
            ) spi_reg(
                .clock(clock),
                .reset(reset),
                .SCLK(SCLK),
                .SS(SS[i]),
                .MOSI(MOSI[i]),
                .MISO(MISO[i]),
                .slave_clock(s_clks[i]),
                .enable(enable),
                .msb_first(msb_first),
                .data_in(spi_data_in[i]),
                .spi_transfer_length(transfer_length),
                .clock_polarity(clock_polarity),
                .latching_edge(latching_edge),
                .ss_polarity(ss_polarity),
                .data_out(spi_data_out[i])
            );
        end
    endgenerate




endmodule
