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


    wire [15:0] assert_delay;
    wire [15:0] deassert_delay;
    wire [7:0] spi_divider;
    wire ss_polarity, sclk_polarity, latching_edge, lsb_first;
    wire [7:0] transfer_length;
    wire [31:0] cu_registers [N_CHANNELS-1:0];

    axil_simple_register_cu #(
        .N_READ_REGISTERS(N_CHANNELS),
        .N_WRITE_REGISTERS(N_CHANNELS),
        .REGISTERS_WIDTH(32),
        .ADDRESS_MASK('h3f)
    ) axi_if(
        .clock(clock),
        .reset(reset),
        .input_registers(cu_registers),
        .output_registers(cu_registers),
        .axil(axi_in)
    );


    assign spi_divider = cu_registers[0][7:0];
    assign ss_polarity = cu_registers[0][8];
    assign sclk_polarity = cu_registers[0][9];
    assign latching_edge = cu_registers[0][10];
    assign lsb_first = cu_registers[0][11];
    assign assert_delay = cu_registers[1][15:0];
    assign deassert_delay = cu_registers[1][31:16];
    assign transfer_length = cu_registers[2];


    reg inner_ss = 0;
    reg sclk_enable = 0;
    reg generated_sclk = 0;

    always_ff @(posedge clock)begin
        sclk <= sclk_polarity ? ~(generated_sclk & sclk_enable): (generated_sclk & sclk_enable);
    end

    assign ss = ss_polarity ? ~inner_ss  : inner_ss;

    /////////////////////////////////////////////////////////
    //         Input latching and input control            //
    /////////////////////////////////////////////////////////
    initial begin
        spi_data_in.ready = 1;
    end

    enum logic [2:0] {
        idle = 0,
        start_delay = 1,
        transmission = 2
    } packet_sender_state = idle;


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

    reg start_register = 0;

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
        .ss_delay({deassert_delay, assert_delay}),
        .ss(inner_ss),
        .sclk_enable(sclk_enable),
        .spi_transfer_length(transfer_length),
        .clock_polarity(sclk_polarity),
        .latching_edge(latching_edge),
        .lsb_first(lsb_first),
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
        if (clk_counter >= spi_divider) begin
            clk_counter <= 3'd0;
            generated_sclk    <= ~generated_sclk;
        end else begin
            clk_counter <= clk_counter + 1'b1;
        end
    end



endmodule
