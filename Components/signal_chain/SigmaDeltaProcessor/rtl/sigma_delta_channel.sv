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


module sigma_delta_channel #(
    parameter DATA_PATH_WIDTH = 24,
    parameter OUTPUT_WIDTH = 16,
    parameter CHANNEL_INDICATOR = 0,
    parameter OUTPUT_SHIFT_SIZE = 8
)(
    input wire clock,
    input wire reset,
    input wire sync,
    input wire sd_data_in,
    input wire sd_clock_in,
    input wire output_clock,
    axi_stream.master data_out
);

    reg [DATA_PATH_WIDTH-1:0]  integration_out;

    sigma_delta_integration_stage #(
        .DATA_PATH_WIDTH(DATA_PATH_WIDTH)
    ) integration_stage (
        .clock(clock),
        .reset(reset),
        .data_in(sd_data_in),
        .modulation_clock(sd_clock_in),
        .data_out(integration_out)
    );

    wire [DATA_PATH_WIDTH-1:0] differentiation_out;

    sigma_delta_differentiation_stage #( 
        .DATA_PATH_WIDTH(DATA_PATH_WIDTH)
    ) diff_stage(
        .clock(clock),
        .reset(reset),
        .samplink_clock(output_clock),
        .data_in(integration_out),
        .data_out(differentiation_out)
    );

    // OUTPUT STAGE
    reg output_clock_del = 0;
    reg [OUTPUT_WIDTH:0] unsigned_out = 0;
    reg [OUTPUT_WIDTH-1:0] adc_data = 0;

    always_comb begin
        if(unsigned_out[OUTPUT_WIDTH])begin
            adc_data <= {OUTPUT_WIDTH-1{1'b1}};
        end else begin
            adc_data <= unsigned_out - (1<<(OUTPUT_WIDTH-1));
        end

    end

    always @(posedge clock) begin

        data_out.valid <= 0;
        output_clock_del <= output_clock;
        if(output_clock & ~output_clock_del) begin
            unsigned_out <= differentiation_out >> OUTPUT_SHIFT_SIZE;
        end

        if(sync)begin
            data_out.data <= adc_data;
            data_out.valid <= 1;
            data_out.dest <= CHANNEL_INDICATOR;
        end
    end

endmodule