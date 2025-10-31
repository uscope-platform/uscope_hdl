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
`include "interfaces.svh"

module SPI_slave#(
    N_CHANNELS=3,
    REGISTERS_WIDTH=16,
    OUTPUT_WIDTH=32
)(
    input reg clock,
    input reg reset,
    output reg data_valid,
    output reg [OUTPUT_WIDTH-1:0] data_out [N_CHANNELS-1:0],
    output reg [N_CHANNELS-1:0] MISO,
    output reg SCLK,
    input wire [N_CHANNELS-1:0] MOSI,
    output reg [N_CHANNELS-1:0] SS,
    axi_lite.slave axi_in,
    axi_stream.slave external_spi_transfer
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
    wire ss_polarity, latching_edge, clock_polarity;

    assign clock_polarity = cu_write_registers[0][0];
    assign latching_edge = cu_write_registers[0][1];
    assign ss_polarity = cu_write_registers[0][2];
    assign transfer_length = cu_write_registers[1];

    axi_stream spi_data_out[N_CHANNELS]();

    genvar i;
    generate
        for(i=0; i<N_CHANNELS; i=i+1) begin : gen_spi_slave_registers
            spi_slave_register #(
                .REGISTERS_WIDTH(REGISTERS_WIDTH)
            ) spi_reg(
                .clock(clock),
                .reset(reset),
                .SCLK(SCLK),
                .SS(SS[i]),
                .MOSI(MOSI[i]),
                .MISO(MISO[i]),
                .spi_transfer_length(transfer_length),
                .clock_polarity(clock_polarity),
                .latching_edge(latching_edge),
                .ss_polarity(ss_polarity),
                .data_out(spi_data_out[i])
            );

            always_ff @(posedge clock) begin
                if(spi_data_out[i].valid) begin
                    data_out[i] <= spi_data_out[i].data;
                    data_valid <= 1;
                end else begin
                    data_valid <= 0;
                end
            end
        end
    endgenerate




endmodule


 /**
       {
        "name": "SpiControlUnit",
        "alias": "SPI",
        "type": "peripheral",
        "registers":[
            {
                "name": "control",
                "offset": "0x0",
                "description": "SPI peripheral control register",
                "direction": "RW",
                "fields":[
                    {
                        "name":"spi_mode",
                        "description": "Deprecated",
                        "start_position": 0,
                        "length": 1
                    },
                    {
                        "name":"divider_setting",
                        "description": "SCLK generator division setting",
                        "start_position": 1,
                        "length": 3
                    },
                    {
                        "name":"spi_transfer_length",
                        "description": "length of the SPI transfer",
                        "start_position": 4,
                        "length": 4
                    },
                    {
                        "name":"spi_direction",
                        "description": "Direction of travel fo the data (MSB or LSB first)",
                        "start_position": 9,
                        "length": 1
                    },
                    {
                        "name":"start_generator_enable",
                        "description": "Enable the internal trigger generator for periodic transfers",
                        "start_position": 12,
                        "length": 1
                    },
                    {
                        "name":"ss_polarity",
                        "description": "Polarity of the Chip Select signal",
                        "start_position": 13,
                        "length": 1
                    },
                    {
                        "name":"ss_deassert_delay_enable",
                        "description": "Enable the addition of delay between CS deassertion and SPI transfer",
                        "start_position": 14,
                        "length": 1
                    },
                    {
                        "name":"transfer_length_choice",
                        "description": "Toggle between internal and external transfer length input",
                        "start_position": 15,
                        "length": 1
                    },
                    {
                        "name":"latching_edge",
                        "description": "Select edge with which the data is transfered",
                        "start_position": 16,
                        "length": 1
                    },
                    {
                        "name":"clock_polarity",
                        "description": "Polarity of the SCLK signal (active high or active low)",
                        "start_position": 17,
                        "length": 1
                    }
                ]
            },
            {
                "name": "ss_delay",
                "offset": "0x4",
                "description": "Delay between the Chip Select signal and the spi transfer",
                "direction": "RW"
            },
            {
                "name": "period",
                "offset": "0x8",
                "description": "Period of the periodic transfer enable generator",
                "direction": "RW"
            },
            {
                "name": "trigger",
                "offset": "0xC",
                "description": "Writing 1 to this register triggers a transfer",
                "direction": "RW"
            },
            {
                "name": "data_1",
                "offset": "0x10",
                "description": "SPI register for the first channel",
                "direction": "RW"
            }
        ]
    }  
    **/
