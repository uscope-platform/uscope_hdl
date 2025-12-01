// Copyright 2024 Filippo Savi
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

module spi_adc_interface #(
    parameter N_CHANNELS=3,
    DATAPATH_WIDTH=32,
    REPORTED_SIZE = DATAPATH_WIDTH,
    parameter [31:0] DESTINATIONS [N_CHANNELS-1:0] = '{N_CHANNELS{0}},
    PRAGMA_MKFG_MODULE_TOP = "SPI"
)(
    input wire clock,
    input wire reset,
    input wire [N_CHANNELS-1:0] MISO,
    output wire SCLK,
    output wire SS,
    input wire sample,
    axi_lite.slave axi_in,
    axi_stream.master data_out
);


    axi_stream spi_transfer();
    assign spi_transfer.valid = sample;
    assign spi_transfer.data = 0;

    wire adc_samples_valid;
    wire [DATAPATH_WIDTH-1:0] adc_samples_data [N_CHANNELS-1:0];

    SPI #(
        .N_CHANNELS(N_CHANNELS),
        .OUTPUT_WIDTH(DATAPATH_WIDTH),
        .PRAGMA_MKFG_MODULE_TOP(PRAGMA_MKFG_MODULE_TOP)
    )adc_spi(
        .clock(clock),
        .reset(reset),
        .data_valid(adc_samples_valid),
        .data_out(adc_samples_data),
        .MISO(MISO),
        .SCLK(SCLK),
        .SS(SS),
        .axi_in(axi_in),
        .external_transfer_length(DATAPATH_WIDTH),
        .external_spi_transfer(spi_transfer)
    );

    reg [$clog2(N_CHANNELS)-1:0] channel_counter = 0;

    initial begin
        data_out.data <= 0;
        data_out.dest <= 0;
    end

    always_ff@(posedge clock)begin
        if(adc_samples_valid)begin
            
            data_out.data <= adc_samples_data[0];
            data_out.user <= get_axis_metadata(REPORTED_SIZE, 0, 0);
            data_out.dest <= DESTINATIONS[0];
            data_out.valid <= 1;
            
            channel_counter <= channel_counter+1;
        end else begin
            if(channel_counter>0)begin
                data_out.data <= adc_samples_data[channel_counter];
                data_out.dest <= DESTINATIONS[channel_counter];
                data_out.valid <= 1;
                if(channel_counter==N_CHANNELS-1)begin
                    channel_counter <= 0;
                end else begin
                    channel_counter <= channel_counter+1;
                end
            end else begin
                data_out.valid <= 0;    
            end
        end
    end

endmodule