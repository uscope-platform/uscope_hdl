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

module spi_master_register #(
    parameter int REGISTERS_WIDTH=16,
    int N_CHANNELS=16,
    int OUTPUT_WIDTH = 32
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
    input wire msb_first,
    input wire ss_polarity,
    input wire start,
    output reg done,
    input wire [REGISTERS_WIDTH-1:0] data_in[N_CHANNELS-1:0],
    input reg [REGISTERS_WIDTH-1:0] data_out[N_CHANNELS-1:0]
);

    function automatic [OUTPUT_WIDTH-1:0] invert_word(
        input [REGISTERS_WIDTH-1:0] data,
        input [7:0] length
    );
        integer i;
        begin
        invert_word = 0;
            for (i = 0; i < length; i = i + 1) begin
                invert_word[i] = data[length-1- i];
            end
        end
    endfunction

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
        data_out = '{default:0};
    end


    enum logic [1:0] {
        spi_idle = 0,
        spi_transfer = 1
    } state = spi_idle;


    wire current_miso;
    assign current_miso = transmission_register[transfer_counter];

    reg [REGISTERS_WIDTH-1:0] transmission_register;

    always_ff @(posedge clock) begin
        if(~reset) begin
            MISO <= 0;
        end
        done <=0;
        sclk_del <= inner_sclk;
        ss_polarity_del <= ss_polarity;
        ss_del <= inner_ss;
        case (state)
            spi_idle: begin
                if(start)begin
                    state <= spi_transfer;
                end
            end
            spi_transfer: begin
                if(inner_sclk & ~sclk_del) begin
                    if(transfer_counter == spi_transfer_length-1) begin
                        state <= spi_idle;
                        done <= 1;
                    end
                    transfer_counter <= transfer_counter +1;
                end
            end
        endcase
    end


endmodule
