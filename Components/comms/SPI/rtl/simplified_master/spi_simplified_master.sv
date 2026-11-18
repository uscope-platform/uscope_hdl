// Copyright 2026` Filippo Savi
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

module spi_simplified_master#(
    N_CHANNELS=3,
    REGISTERS_WIDTH=16,
    OUTPUT_WIDTH=32,
    DEFAULT_CONFIG = 0,
    DEFAULT_DELAYS = 0,
    DEFAULT_LENGTH = 16,
    STARTING_DEST = 0,
    MAX_PACKET_SIZE = N_CHANNELS
)(
    input wire clock,
    input wire reset,

    input wire [N_CHANNELS-1:0] miso,
    output reg sclk,
    output reg [N_CHANNELS-1:0] mosi,
    output reg ss,

    axi_lite.slave axi_in,
    axi_stream.slave spi_data_in,
    axi_stream.master spi_data_out
);


    typedef struct packed{
        reg lsb_first;
        reg latching_edge;
        reg sclk_polarity;
        reg ss_polarity;
    } wire_format;

    typedef struct packed{
        reg [19:0] padding;
        reg lsb_first;
        reg latching_edge;
        reg sclk_polarity;
        reg ss_polarity;
        reg [7:0] spi_divider;
    } spi_simple_master_control_register;

    typedef struct {
        spi_simple_master_control_register control;
        spi_master_types::delays ss_delay;
        reg [31:0] transfer_length;
    } spi_simple_master_registers;

    spi_simple_master_registers registers;

    axil_simple_register_cu #(
        .READ_TYPE(spi_simple_master_registers),
        .WRITE_TYPE(spi_simple_master_registers),
        .INITIAL_OUTPUT_VALUES('{
            control: DEFAULT_CONFIG,
            ss_delay: DEFAULT_DELAYS,
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

    reg inner_ss = 0;
    reg sclk_enable = 0;
    reg generated_sclk = 0;

    always_ff @(posedge clock)begin
        sclk <= registers.control.sclk_polarity ? ~(generated_sclk & sclk_enable): (generated_sclk & sclk_enable);
    end

    assign ss = registers.control.ss_polarity ? ~inner_ss  : inner_ss;

    /////////////////////////////////////////////////////////
    //         Input latching and input control            //
    /////////////////////////////////////////////////////////
    initial begin
        spi_data_in.ready = 1;
    end

    typedef enum logic [2:0] {
        idle = 0,
        start_delay = 1,
        transmission = 2
    } packet_sender_state_t;
    packet_sender_state_t packet_sender_state = idle;

    wire register_done;

    reg [15:0] packet_length = 0;
    reg [15:0] transfered_words = 0;

    reg [REGISTERS_WIDTH-1:0] input_buffer [MAX_PACKET_SIZE-1:0] = '{default:0};

    reg  [REGISTERS_WIDTH-1:0] transmit_data [N_CHANNELS-1:0] = '{default:0};
    wire [REGISTERS_WIDTH-1:0] received_data [N_CHANNELS-1:0];
    reg transmission_start = 0;

    always_ff @(posedge clock)begin
            case (packet_sender_state)
                idle:begin
                    transfered_words <= 0;
                    if(spi_data_in.valid)begin
                        packet_length <= packet_length+1;
                        input_buffer[spi_data_in.dest-STARTING_DEST] <= spi_data_in.data;
                        if(spi_data_in.tlast)begin
                            packet_sender_state<= start_delay;
                            spi_data_in.ready <= 0;
                        end
                    end
                end
                start_delay: begin
                    for(int i = 0; i< N_CHANNELS; i++)begin
                        transmit_data[i] <= input_buffer[transfered_words+i];
                    end
                    if(~generated_sclk)begin
                        packet_sender_state<= transmission;
                        transfered_words <= transfered_words+N_CHANNELS;
                        transmission_start <= 1;
                    end
                end
                transmission: begin
                    transmission_start <= 0;
                    if(register_done)begin
                        if(transfered_words >= packet_length) begin
                            packet_sender_state<= idle;
                            packet_length <= 0;
                            spi_data_in.ready <= 1;
                        end else begin
                            packet_sender_state<= start_delay;
                        end
                    end
                end
            endcase
        end

    spi_master_register #(
        .REGISTERS_WIDTH(16),
        .N_CHANNELS(N_CHANNELS),
        .OUTPUT_WIDTH(OUTPUT_WIDTH)
    )shrs(
        .clock(clock),
        .reset(reset),
        .sclk(generated_sclk),
        .mosi(mosi),
        .miso(miso),
        .ss_delay(registers.ss_delay),
        .ss(inner_ss),
        .sclk_enable(sclk_enable),
        .spi_transfer_length(registers.transfer_length),
        .lsb_first(registers.control.lsb_first),
        .start(transmission_start),
        .done(register_done),
        .data_in(transmit_data),
        .data_out(received_data)
    );

    /////////////////////////////////////////////////////////
    //                  clock generation                   //
    /////////////////////////////////////////////////////////


    logic [2:0] clk_counter = 0;

    always_ff @(posedge clock) begin
        if (clk_counter >= registers.control.spi_divider) begin
            clk_counter <= 3'd0;
            generated_sclk    <= ~generated_sclk;
        end else begin
            clk_counter <= clk_counter + 1'b1;
        end
    end



endmodule


 /**
    {
        "name": "spi_simplified_master",
        "type": "parametric_peripheral",
        "registers":[
            {
                "name": "control",
                "n_regs": ["1"],
                "description": "SPI master control register",
                "direction": "RW",
                "fields":[
                    {
                        "name":"spi_divider",
                        "description": "SPI clock divider",
                        "start_position": 0,
                        "n_fields":["1"],
                        "length": 8
                    },
                    {
                        "name":"ss_polarity",
                        "description": "Slave select polarity",
                        "start_position": 8,
                        "n_fields":["1"],
                        "length": 1
                    },
                    {
                        "name":"sclk_polarity",
                        "description": "SPI clock idle polarity (CPOL)",
                        "start_position": 9,
                        "n_fields":["1"],
                        "length": 1
                    },
                    {
                        "name":"latching_edge",
                        "description": "SPI data latching edge (CPHA)",
                        "start_position": 10,
                        "n_fields":["1"],
                        "length": 1
                    },
                    {
                        "name":"lsb_first",
                        "description": "Bit transmission order (1 = LSB first)",
                        "start_position": 11,
                        "n_fields":["1"],
                        "length": 1
                    }
                ]
            },
            {
                "name": "ss_delay",
                "n_regs": ["1"],
                "description": "Slave select assert/deassert delays",
                "direction": "RW",
                "fields":[
                    {
                        "name":"assert_delay",
                        "description": "SS assertion delay in clock cycles",
                        "start_position": 0,
                        "n_fields":["1"],
                        "length": 16
                    },
                    {
                        "name":"deassert_delay",
                        "description": "SS deassertion delay in clock cycles",
                        "start_position": 16,
                        "n_fields":["1"],
                        "length": 16
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
