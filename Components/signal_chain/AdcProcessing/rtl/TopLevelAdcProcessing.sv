// Copyright (C) : 10/22/2018, 11:25:20 AM Filippo Savi - All Rights Reserved

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

module TopLevelAdcProcessing (
    input logic MISO,
    output logic SS,
    output logic SCLK
);

    APB apb();
    Simplebus s();
    wire clk, rst;
    wire [15:0] data_a;

    Zynq_wrapper TEST(
        .APB(apb),
        .Clock(clk),
        .Reset(rst));
        
    APB_to_Simplebus bridge(
        .PCLK(clk),
        .PRESETn(rst),
        .apb(apb),
        .spb(s));


    AdcProcessing UUT(
        .clock(clk),
        .reset(rst),
        .simple_bus(s),
        .spi_data_in_a(MISO),
        .spi_cnv_start(SS),
        .spi_sck_out(SCLK),
        .data_a(data_a)
    );


endmodule