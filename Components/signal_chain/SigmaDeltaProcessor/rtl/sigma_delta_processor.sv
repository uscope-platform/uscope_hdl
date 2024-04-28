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
    parameter MAIN_DECIMATION_RATIO = 256,
    parameter COMPARATOR_DECIMATION_RATIO = 0
    
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
        if(MAIN_DECIMATION_RATIO!=4 && MAIN_DECIMATION_RATIO!=8 && MAIN_DECIMATION_RATIO!=16 && MAIN_DECIMATION_RATIO!=32 && MAIN_DECIMATION_RATIO!=64 && MAIN_DECIMATION_RATIO!=128 && MAIN_DECIMATION_RATIO!=256) begin
            $fatal(1,"INVALID DECIMATION RATIO: The decimation ratio must be one of the following values [4, 8, 16, 32, 64, 128, 256]\n\tCurrent value%d", MAIN_DECIMATION_RATIO);
        end
    endgenerate

    localparam main_clock_selector = $clog2(MAIN_DECIMATION_RATIO)-1;
    //                                           256 128 64  32  16  8  4
    localparam [7:0] filter_width_map [6:0] = '{ 25, 22, 20, 16, 13, 10, 7 };
    localparam [7:0] output_width_map [6:0] = '{ 16, 16, 16, 14, 12, 8, 6 };
    localparam [7:0] output_shift_map [6:0] = '{ 8,  5,  2,  1,  0, 1, 0};


    localparam [7:0] main_filter_width = filter_width_map[main_clock_selector-1];
    localparam [7:0] main_output_width = output_width_map[main_clock_selector-1];
    localparam [7:0] main_output_shift = output_shift_map[main_clock_selector-1];


    localparam comparator_enabled = COMPARATOR_DECIMATION_RATIO>0;

    localparam comparator_clock_selector = $clog2(MAIN_DECIMATION_RATIO)-1;
    

    localparam [7:0] comparator_filter_width = filter_width_map[comparator_clock_selector-1];
    localparam [7:0] comparator_output_width = output_width_map[comparator_clock_selector-1];
    localparam [7:0] comparator_output_shift = output_shift_map[comparator_clock_selector-1];

    wire main_sampling_clock, comparator_sampling_clock;

    sigma_delta_clock_generator clk_gen (
        .clock(clock),
        .reset(reset),
        .main_clock_selector(main_clock_selector),
        .comparator_clock_selector(comparator_clock_selector),
        .main_sampling_clock(main_sampling_clock),
        .comparator_sampling_clock(comparator_sampling_clock),
        .sd_clock(clock_out)
    );
    genvar i;

    axi_stream main_data_out[N_CHANNELS]();
    axi_stream comparator_data_out[N_CHANNELS]();
    generate
        for (i = 0; i<N_CHANNELS; i++) begin
            sigma_delta_channel #(
                .DATA_PATH_WIDTH(main_filter_width),
                .OUTPUT_WIDTH(main_output_width),
                .OUTPUT_SHIFT_SIZE(main_output_shift),
                .CHANNEL_INDICATOR(i)
            ) data_channel (
                .clock(clock),
                .reset(reset),
                .sd_data_in(data_in[i]),
                .sd_clock_in(clock_out),
                .output_clock(main_sampling_clock),
                .data_out(main_data_out[i])
            );
        end

    if(comparator_enabled)begin

      
        for (i = 0; i<N_CHANNELS; i++) begin
            sigma_delta_channel #(
                .DATA_PATH_WIDTH(comparator_filter_width),
                .OUTPUT_WIDTH(comparator_output_width),
                .OUTPUT_SHIFT_SIZE(comparator_output_shift),
                .CHANNEL_INDICATOR(i)
            ) data_channel (
                .clock(clock),
                .reset(reset),
                .sd_data_in(data_in[i]),
                .sd_clock_in(clock_out),
                .output_clock(comparator_sampling_clock),
                .data_out(comparator_data_out[i])
            );
        end
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
        .stream_in(main_data_out),
        .stream_out(data_out)
    );




endmodule