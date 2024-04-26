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
    parameter DATA_PATH_WIDTH = 24,
    parameter N_CHANNELS = 2
)(
    input wire clock,
    input wire reset,
    input wire [N_CHANNELS-1:0] data_in,
    input wire sync,
    axi_lite.slave axi_in,
    axi_stream.master data_out_1,
    axi_stream.master data_out_2,
    output wire clock_out
);


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



    reg [7:0]   sampling_ctr;
    wire samplink_clk;

    // DECIMATION CLOCK GENERATOR
    always@(posedge clock_out_inner) begin
        if(~reset) begin
            sampling_ctr  <= 0;
        end else begin
            sampling_ctr <= sampling_ctr + 1;
        end
    end

    assign samplink_clk =  sampling_ctr[7];



    sigma_delta_channel #(.DATA_PATH_WIDTH(DATA_PATH_WIDTH)) channel_a (
        .clock(clock),
        .reset(reset),
        .sd_data_in(data_in[0]),
        .sd_clock_in(clock_out),
        .output_clock(samplink_clk),
        .data_out(data_out_1)
    );

    sigma_delta_channel #(.DATA_PATH_WIDTH(DATA_PATH_WIDTH)) channel_b (
        .clock(clock),
        .reset(reset),
        .sd_data_in(data_in[1]),
        .sd_clock_in(clock_out),
        .output_clock(samplink_clk),
        .data_out(data_out_2)
    );


endmodule