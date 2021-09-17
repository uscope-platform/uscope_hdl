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

module ad2s1210 #(parameter BASE_ADDRESS = 32'h43c00000)(
    input wire clock,
    input wire reset,
    input wire read_angle,
    input wire read_speed,
    output logic MOSI,
    input logic MISO,
    inout logic SS,
    inout logic SCLK,
    output reg R_RESET,
    output reg R_SAMPLE,
    output reg [1:0] R_A,
    output reg [1:0] R_RES,
    axi_stream.master data_out,
    Simplebus.slave sb
);
    
    
    wire SPI_ready, SPI_valid;
    wire [4:0] spi_transfer_length;
    wire [31:0] SPI_data;

    defparam xbar.SLAVE_1_LOW = BASE_ADDRESS;
    defparam xbar.SLAVE_1_HIGH = BASE_ADDRESS+'h2C;
    defparam xbar.SLAVE_2_LOW = BASE_ADDRESS+'h2C;
    defparam xbar.SLAVE_2_HIGH = BASE_ADDRESS+'h2C+'h100;
    
    Simplebus spi_sb();
    Simplebus cu_sb();
    SimplebusInterconnect_M1_S2 xbar(
        .clock(clock),
        .master(sb),
        .slave_1(cu_sb),
        .slave_2(spi_sb)
    );


    defparam CU.BASE_ADDRESS = BASE_ADDRESS;
    ad2s1210_cu CU(
        .clock(clock),
        .reset(reset),
        .read_angle(read_angle),
        .read_speed(read_speed),
        .SPI_ready(SPI_ready),
        .SPI_valid(SPI_valid),
        .SPI_data_out(SPI_data),
        .SPI_data_in(unpacked_spi_data[0]),
        .spi_transfer_length(spi_transfer_length),
        .mode(R_A),
        .resolution(R_RES),
        .sample(R_SAMPLE),
        .rdc_reset(R_RESET),
        .data_out(data_out),
        .sb(cu_sb)
    );   
    
    wire data_valid;
    wire [31:0] unpacked_spi_data [0:0];
    
    defparam ext_interface.BASE_ADDRESS = BASE_ADDRESS+'h2C;
    defparam ext_interface.SS_POLARITY_DEFAULT = 1;
    defparam ext_interface.N_CHANNELS = 1;
    SPI ext_interface(
        .clock(clock),
        .reset(reset),
        .external_transfer_length(spi_transfer_length),
        .MISO(MISO),
        .SCLK(SCLK),
        .MOSI(MOSI),
        .SS(SS),
        .simple_bus(spi_sb),
        .SPI_write_valid(SPI_valid),
        .SPI_write_data(SPI_data),
        .SPI_write_ready(SPI_ready),
        .data_valid(data_valid),
        .data_out(unpacked_spi_data)
    );

endmodule