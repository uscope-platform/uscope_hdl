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
    input wire sclk,
    input wire [N_CHANNELS-1:0] miso,
    output reg [N_CHANNELS-1:0] mosi,
    output reg sclk_enable,
    output reg ss,
    input wire [7:0] spi_transfer_length,
    input wire [31:0] ss_delay,
    input wire clock_polarity,
    input wire latching_edge,
    input wire lsb_first,
    input wire start,
    output reg done,
    input wire [REGISTERS_WIDTH-1:0] data_in[N_CHANNELS-1:0],
    input reg [REGISTERS_WIDTH-1:0] data_out[N_CHANNELS-1:0]
);

    typedef logic [REGISTERS_WIDTH-1:0] io_bus_t [N_CHANNELS-1:0];
    function io_bus_t invert_word(
        input io_bus_t data,
        input [7:0] length
    );
        integer i, j;
        begin
            for(j = 0; j<N_CHANNELS; j++)begin
                invert_word[j] = 0;
                for (i = 0; i < length; i = i + 1) begin
                    invert_word[j][i] = data[j][length-1- i];
                end
            end
        end
    endfunction

    reg [7:0] transfer_counter = 0;

    reg [REGISTERS_WIDTH-1:0] spi_register = '{default:0};

    reg inner_sclk, sclk_del;

    always_comb begin
        if(latching_edge) begin // CPOL=0, CPHA=1
            inner_sclk = ~sclk;
        end else begin // CPOL=0, CPHA=0
            inner_sclk = sclk;
        end
    end

    initial begin
        data_out = '{default:0};
    end


    enum logic [2:0] {
        spi_idle = 0,
        spi_assert_delay = 1,
        spi_enable_clock = 2,
        spi_transfer = 3,
        spi_disable_clock = 4,
        spi_deassert_delay = 5
    } state = spi_idle;

    reg [REGISTERS_WIDTH-1:0] transmission_register [N_CHANNELS-1:0] = '{default:0};

    reg current_mosi [N_CHANNELS-1:0];
    genvar i;
    generate
        for ( i = 0; i<N_CHANNELS; i++) begin
            assign current_mosi[i] = transmission_register[i][transfer_counter];
        end
    endgenerate

    wire [N_CHANNELS-1:0] first_mosi;
    generate
        for ( i = 0; i<N_CHANNELS; i++) begin
            assign first_mosi[i] = lsb_first ? data_in[i][0] : data_in[i][spi_transfer_length-1];
        end
    endgenerate

    reg [15:0] assert_counter = 0;


    always_ff @(posedge clock) begin
        done <=0;
        sclk_del <= inner_sclk;
        case (state)
            spi_idle: begin
                sclk_enable<= 0;
                transfer_counter <= 0;
                mosi <= '{default:0};
                if(start)begin
                    state <= spi_assert_delay;
                    ss <=1;
                    if(lsb_first) begin
                        transmission_register <= data_in;
                    end else begin
                        transmission_register <= invert_word(data_in, spi_transfer_length);
                    end
                    mosi[0] <= first_mosi;
                    mosi[1] <= first_mosi;
                    mosi[2] <= first_mosi;
                    mosi[3] <= first_mosi;
                end
            end
            spi_assert_delay:begin
                if(inner_sclk & ~sclk_del) begin
                    if(assert_counter == ss_delay[15:0])begin
                        state <= spi_enable_clock;
                        assert_counter<= 0;
                    end else begin
                        assert_counter <= assert_counter+1;
                    end
                end
            end
            spi_enable_clock: begin
                if(~inner_sclk & sclk_del)begin
                    sclk_enable <= 1;
                    state <= spi_transfer;
                end
            end
            spi_transfer: begin
                if(inner_sclk & ~sclk_del) begin
                    mosi[0] <= current_mosi[0];
                    mosi[1] <= current_mosi[1];
                    mosi[2] <= current_mosi[2];
                    mosi[3] <= current_mosi[3];
                    if(transfer_counter == spi_transfer_length-1) begin
                        state <= spi_disable_clock;
                    end
                    transfer_counter <= transfer_counter +1;
                end
            end
            spi_disable_clock: begin
                if(~inner_sclk & sclk_del)begin
                    sclk_enable <= 0;
                    state <= spi_deassert_delay;
                end
            end
            spi_deassert_delay: begin
                if(inner_sclk & ~sclk_del) begin
                    if(assert_counter == ss_delay[31:16])begin
                        state <= spi_idle;
                        ss <= 0;
                        done <= 1;
                        assert_counter<= 0;
                    end else begin
                        assert_counter <= assert_counter+1;
                    end
                end
            end
        endcase
    end


endmodule
