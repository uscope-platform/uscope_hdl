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
    OUTPUT_WIDTH=32,
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
    axi_stream.slave spi_data_in [N_CHANNELS],
    axi_stream.master spi_data_out [N_CHANNELS]
);


    typedef struct packed{
        reg [27:0] padding;
        reg msb_first;
        reg ss_polarity;
        reg latching_edge;
        reg clock_polarity;
    } spi_slave_control_register;

    typedef struct {
        spi_slave_control_register control;
        reg [31:0] transfer_length;
    } spi_slave_registers;

    spi_slave_registers registers;

    axil_simple_register_cu #(
        .READ_TYPE(spi_slave_registers),
        .WRITE_TYPE(spi_slave_registers),
        .INITIAL_OUTPUT_VALUES('{
            control: DEFAULT_CONFIG,
            transfer_length: DEFAULT_LENGTH
        }),
        .ADDRESS_MASK('hff)
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(registers),
        .output_registers(registers),
        .axil(axi_in)
    );



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
                .msb_first(registers.control.msb_first),
                .data_in(spi_data_in[i]),
                .spi_transfer_length(registers.transfer_length),
                .clock_polarity(registers.control.clock_polarity),
                .latching_edge(registers.control.latching_edge),
                .ss_polarity(registers.control.ss_polarity),
                .data_out(spi_data_out[i])
            );
        end
    endgenerate




endmodule


 /**
    {
        "name": "SPI_slave",
        "type": "parametric_peripheral",
        "registers":[
            {
                "name": "control",
                "n_regs": ["1"],
                "description": "SPI slave control register",
                "direction": "RW",
                "fields":[
                    {
                        "name":"clock_polarity",
                        "description": "SPI clock idle polarity (CPOL)",
                        "start_position": 0,
                        "n_fields":["1"],
                        "length": 1
                    },
                    {
                        "name":"latching_edge",
                        "description": "SPI data latching edge (CPHA)",
                        "start_position": 1,
                        "n_fields":["1"],
                        "length": 1
                    },
                    {
                        "name":"ss_polarity",
                        "description": "Slave select polarity",
                        "start_position": 2,
                        "n_fields":["1"],
                        "length": 1
                    },
                    {
                        "name":"msb_first",
                        "description": "Bit transmission order (1 = MSB first)",
                        "start_position": 3,
                        "n_fields":["1"],
                        "length": 1
                    }
                ]
            },
            {
                "name": "transfer_length",
                "n_regs": ["1"],
                "description": "SPI transfer length in bits",
                "direction": "RW",
                "fields":[]
            }
        ]
    }
 **/
