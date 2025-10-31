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

module spi_slave_register #(
    parameter int REGISTERS_WIDTH=16
    )(
    input wire clock,
    input wire reset,
    input wire SCLK,
    input wire SS,
    input wire MOSI,
    output reg MISO,
    input wire [7:0] spi_transfer_length,
    input wire clock_polarity,
    input wire latching_edge,
    input wire ss_polarity,
    axi_stream.master data_out
);



    reg [7:0] transfer_counter = 0;

    reg [REGISTERS_WIDTH-1:0] spi_register = '{default:0};

    reg ss_active = 0;
    reg ss_del = 0;

    reg inner_sclk, sclk_del;
    reg inner_ss;
    reg ss_polarity_del;

    always_comb begin : io_conditioning
        if(ss_polarity)begin
            inner_ss= ~SS;
        end else begin
            inner_ss = SS;
        end
        if(clock_polarity) begin
            if(latching_edge) begin // CPOL=1, CPHA=1
                inner_sclk = ~SCLK;
            end else begin // CPOL=1, CPHA=0
                inner_sclk = SCLK;
            end
        end else begin
            if(latching_edge) begin // CPOL=0, CPHA=1
                inner_sclk = ~SCLK;
            end else begin // CPOL=0, CPHA=0
                inner_sclk = SCLK;
            end
        end
    end

    initial begin
        data_out.data <= 0;
        data_out.valid <= 0;
        data_out.dest <= 0;
        data_out.user <= 0;
        data_out.tlast <= 0;
    end


    enum logic [1:0] {
        spi_idle = 0,
        spi_transfer = 1,
        spi_wait_deassert = 2
    } state = spi_idle;

    wire[REGISTERS_WIDTH-1:0] shifted_data;
    assign shifted_data = {MOSI, spi_register[REGISTERS_WIDTH-1:1]};

    always_ff @(posedge clock) begin
        sclk_del <= inner_sclk;
        ss_polarity_del <= ss_polarity;
        ss_del <= inner_ss;
        case (state)
            spi_idle: begin
                if(inner_ss && ~ss_del && ~(ss_polarity_del ^ ss_polarity)) begin
                    state <= spi_transfer;
                    ss_active <= 1;
                    transfer_counter <= spi_transfer_length-1;
                end
            end
            spi_transfer: begin
                if(inner_sclk & ~sclk_del) begin
                    if(transfer_counter == 0) begin
                        state <= spi_wait_deassert;
                        data_out.data <= shifted_data>>(REGISTERS_WIDTH - spi_transfer_length);
                        data_out.valid <= 1;
                    end
                    transfer_counter <= transfer_counter -1;
                    spi_register <= shifted_data;
                    MISO <= spi_register[REGISTERS_WIDTH - spi_transfer_length];
                end
            end
            spi_wait_deassert: begin
            if(~inner_ss && ss_del) begin
                data_out.valid <= 0;
                state <= spi_idle;
                ss_active <= 0;
                transfer_counter <= spi_transfer_length-1;
                spi_register <= '0;
            end
            end
        endcase
    end


endmodule
