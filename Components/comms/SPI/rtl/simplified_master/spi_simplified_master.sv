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
    DEFAULT_LENGTH = 16
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

    wire register_done;

    reg[REGISTERS_WIDTH-1:0] transmit_data [N_CHANNELS-1:0] = '{default:0};
    wire[REGISTERS_WIDTH-1:0] received_data [N_CHANNELS-1:0];
    reg transmission_start = 0;
    reg transmission_done = 0;
    reg to_start = 0;
    always_ff @(posedge clock)begin
        transmission_start <= 0;
        if(spi_data_in.valid)begin
            transmit_data[spi_data_in.dest] <= spi_data_in.data;
            if(spi_data_in.tlast)begin
                to_start<=1;
                spi_data_in.ready <= 0;
            end
        end
        if(register_done)begin
            spi_data_in.ready <= 1;
        end
        if(to_start & ~generated_sclk)begin
            transmission_start <= 1;
            to_start <= 0;
        end
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
    //                transmission control                 //
    /////////////////////////////////////////////////////////

    enum logic [2:0]{
        idle = 0,
        wait_ss_assert = 1,
        transfer = 2,
        wait_ss_deassert =3
    } spi_state = idle;


    /////////////////////////////////////////////////////////
    //                  clock generation                   //
    /////////////////////////////////////////////////////////


    logic [2:0] clk_counter = 0;

    initial begin
        generated_sclk =0;
    end
    always_ff @(posedge clock) begin
        if (clk_counter >= spi_divider) begin
            clk_counter <= 3'd0;
            generated_sclk    <= ~generated_sclk;
        end else begin
            clk_counter <= clk_counter + 1'b1;
        end
    end



endmodule
