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

module SPI #(
    SS_POLARITY_DEFAULT=0,
    N_CHANNELS=3,
    OUTPUT_WIDTH=32,
    PRAGMA_MKFG_MODULE_TOP = "SPI",
    SPI_MODE="MASTER"
)(
    input logic clock,
    input logic reset,
    input logic [4:0] external_transfer_length,
    output logic data_valid,
    output logic [OUTPUT_WIDTH-1:0] data_out [N_CHANNELS-1:0],
    input logic [N_CHANNELS-1:0] MISO,
    output logic SCLK,
    output logic [N_CHANNELS-1:0] MOSI,
    output logic SS,
    axi_lite.slave axi_in,
    axi_stream.slave external_spi_transfer
);


generate
    if(SPI_MODE == "MASTER") begin : gen_master


        SPI_master #(
            .SS_POLARITY_DEFAULT(SS_POLARITY_DEFAULT),
            .N_CHANNELS(N_CHANNELS),
            .OUTPUT_WIDTH(OUTPUT_WIDTH),
            .PRAGMA_MKFG_MODULE_TOP(PRAGMA_MKFG_MODULE_TOP)
        )master_module(
            .clock(clock),
            .reset(reset),
            .external_transfer_length(external_transfer_length),
            .data_valid(data_valid),
            .data_out(data_out),
            .MISO(MISO),
            .SCLK(SCLK),
            .MOSI(MOSI),
            .SS(SS),
            .axi_in(axi_in),
            .external_spi_transfer(external_spi_transfer)
        );



    end
    else begin : gen_slave
        // SPI_slave instantiation would go here
        // For now, we can leave it unimplemented or raise an error
        initial begin
            $error("SPI slave mode is not implemented yet.");
        end
    end
endgenerate


endmodule


 /**
       {
        "name": "SpiControlUnit",
        "alias": "SPI",
        "type": "parametric_peripheral",
        "registers":[
            {
                "name": "control",
                "n_regs": ["1"],
                "description": "SPI peripheral control register",
                "direction": "RW",
                "fields":[
                    {
                        "name":"spi_mode",
                        "description": "Deprecated",
                        "n_fields":["1"],
                        "start_position": 0,
                        "length": 1
                    },
                    {
                        "name":"divider_setting",
                        "description": "SCLK generator division setting",
                        "n_fields":["1"],
                        "start_position": 1,
                        "length": 3
                    },
                    {
                        "name":"spi_transfer_length",
                        "description": "length of the SPI transfer",
                        "n_fields":["1"],
                        "start_position": 4,
                        "length": 4
                    },
                    {
                        "name":"spi_direction",
                        "description": "Direction of travel fo the data (MSB or LSB first)",
                        "n_fields":["1"],
                        "start_position": 9,
                        "length": 1
                    },
                    {
                        "name":"start_generator_enable",
                        "description": "Enable the internal trigger generator for periodic transfers",
                        "n_fields":["1"],
                        "start_position": 12,
                        "length": 1
                    },
                    {
                        "name":"ss_polarity",
                        "description": "Polarity of the Chip Select signal",
                        "n_fields":["1"],
                        "start_position": 13,
                        "length": 1
                    },
                    {
                        "name":"ss_deassert_delay_enable",
                        "description": "Enable the addition of delay between CS deassertion and SPI transfer",
                        "n_fields":["1"],
                        "start_position": 14,
                        "length": 1
                    },
                    {
                        "name":"transfer_length_choice",
                        "description": "Toggle between internal and external transfer length input",
                        "n_fields":["1"],
                        "start_position": 15,
                        "length": 1
                    },
                    {
                        "name":"latching_edge",
                        "description": "Select edge with which the data is transfered",
                        "n_fields":["1"],
                        "start_position": 16,
                        "length": 1
                    },
                    {
                        "name":"clock_polarity",
                        "description": "Polarity of the SCLK signal (active high or active low)",
                        "n_fields":["1"],
                        "start_position": 17,
                        "length": 1
                    }
                ]
            },
            {
                "name": "ss_delay",
                "n_regs": ["1"],
                "description": "Delay between the Chip Select signal and the spi transfer",
                "fields":[],
                "direction": "RW"
            },
            {
                "name": "period",
                "n_regs": ["1"],
                "description": "Period of the periodic transfer enable generator",
                "fields":[],
                "direction": "RW"
            },
            {
                "name": "trigger",
                "n_regs": ["1"],
                "description": "Writing 1 to this register triggers a transfer",
                "fields":[],
                "direction": "RW"
            },
            {
                "name": "data_1",
                "n_regs": ["1"],
                "description": "SPI register for the first channel",
                "fields":[],
                "direction": "RW"
            }
        ]
    }  
    **/
