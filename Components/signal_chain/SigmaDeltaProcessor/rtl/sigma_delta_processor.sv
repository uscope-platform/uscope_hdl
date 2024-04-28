// Copyright 2023 Filippo Savi
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

module sigma_delta_processor #(
    parameter N_CHANNELS = 2,
    parameter DECIMATION_RATIO = 256
)(
    input wire clock,
    input wire reset,
    input wire [N_CHANNELS-1:0] data_in,
    input wire sync,
    axi_lite.slave axi_in,
    axi_stream.master data_out,
    output wire clock_out
);


    generate
        if(DECIMATION_RATIO!=4 && DECIMATION_RATIO!=8 && DECIMATION_RATIO!=16 && DECIMATION_RATIO!=32 && DECIMATION_RATIO!=64 && DECIMATION_RATIO!=128 && DECIMATION_RATIO!=256) begin
            $fatal(1,"INVALID DECIMATION RATIO: The decimation ratio must be one of the following values [4, 8, 16, 32, 64, 128, 256]\n\tCurrent value%d", DECIMATION_RATIO);
        end
    endgenerate

    localparam clock_selector = $clog2(DECIMATION_RATIO)-1;
    //                                           256 128 64  32  16  8  4
    localparam [7:0] filter_width_map [6:0] = '{ 25, 22, 20, 16, 13, 10, 7 };
    localparam [7:0] output_width_map [6:0] = '{ 16, 16, 16, 14, 12, 8, 6 };
    localparam [7:0] output_shift_map [6:0] = '{ 8,  5,  2,  1,  0, 1, 0};


    localparam [7:0] filter_width = filter_width_map[clock_selector-1];
    localparam [7:0] output_width = output_width_map[clock_selector-1];
    localparam [7:0] output_shift = output_shift_map[clock_selector-1];

    reg mod_clk;
    reg [4:0] modulator_clkgen = 0;

    always_ff @(posedge clock) begin
        mod_clk <= 0;
        if(modulator_clkgen==1)begin
            modulator_clkgen <= 0;
            mod_clk <= 1;
        end else begin
            modulator_clkgen <= modulator_clkgen+1;
        end
    end
    
    reg clock_out_inner = 0;
    assign clock_out = clock_out_inner;
    
    always_ff @(posedge clock)begin
        if(mod_clk) clock_out_inner <= ~clock_out_inner;
    end



    reg [7:0] sampling_ctr = 0;
    wire samplink_clk;

    reg clock_out_inner_del;

    always@(posedge clock) begin
        clock_out_inner_del <= clock_out_inner;
        if(clock_out_inner & ~clock_out_inner_del) sampling_ctr <= sampling_ctr + 1;
    end

    assign samplink_clk =  sampling_ctr[clock_selector];

    genvar i;

    axi_stream channel_data_out[N_CHANNELS]();

    generate
        for (i = 0; i<N_CHANNELS; i++) begin
            sigma_delta_channel #(
                .DATA_PATH_WIDTH(filter_width),
                .OUTPUT_WIDTH(output_width),
                .OUTPUT_SHIFT_SIZE(output_shift),
                .CHANNEL_INDICATOR(i)
            ) data_channel (
                .clock(clock),
                .reset(reset),
                .sd_data_in(data_in[i]),
                .sd_clock_in(clock_out),
                .output_clock(samplink_clk),
                .data_out(channel_data_out[i])
            );
        end

    endgenerate


    axi_stream_combiner #(
        .INPUT_DATA_WIDTH(32), 
        .OUTPUT_DATA_WIDTH(32), 
        .DEST_WIDTH(8), 
        .USER_WIDTH(8),
        .BUFFER_DEPTH(4),
        .N_STREAMS(N_CHANNELS)
    )output_combiner(
        .clock(clock),
        .reset(reset),
        .stream_in(channel_data_out),
        .stream_out(data_out)
    );


endmodule