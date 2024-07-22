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
    parameter MANCHESER_CODING = "FALSE",
    parameter SAMPLING_EDGE = "POSITIVE",
    parameter PROCESSING_RESOLUTION = 24,
    parameter RESULT_RESOLUTION = 16,
    parameter OUTPUT_SIZE = 32,
    parameter CHANNEL_INDICATOR = 0,
    parameter OUTPUT_SHIFT_SIZE = 8,
    parameter OUTPUT_VALID_DELAY = 4
)(
    input wire clock,
    input wire reset,
    input wire sync,
    input wire sd_data_in,
    input wire sd_clock_in,
    input wire signed [15:0] offset,
    input wire output_clock,
    axi_stream.master data_out
);



    wire filter_input;

    generate  
        if(MANCHESER_CODING=="TRUE")begin

            sigma_delta_manchester_decoder input_decoder(
                .clock(clock),
                .sd_data_in(sd_data_in),
                .sd_clock_in(sd_clock_in),
                .decoded_data(filter_input)
            );

        end else begin
            reg sd_clock_in_del = 0;
            reg registered_in = 0;

            always_ff @( posedge clock) begin 
                sd_clock_in_del <= sd_clock_in;
                if(SAMPLING_EDGE=="POSITIVE")begin
                    if(!sd_clock_in_del & sd_clock_in)begin
                        registered_in <= sd_data_in;
                    end 
                end else begin
                    if(sd_clock_in_del & !sd_clock_in)begin
                        registered_in <= sd_data_in;
                    end
                end

            end
            assign filter_input = registered_in;
        end
    endgenerate


    reg [PROCESSING_RESOLUTION-1:0]  integration_out;

    sigma_delta_integration_stage #(
        .PROCESSING_RESOLUTION(PROCESSING_RESOLUTION)
    ) integration_stage (
        .clock(clock),
        .reset(reset),
        .data_in(filter_input),
        .modulation_clock(sd_clock_in),
        .data_out(integration_out)
    );

    wire [PROCESSING_RESOLUTION-1:0] differentiation_out;
    wire differentiation_valid;
    
    sigma_delta_differentiation_stage #( 
        .PROCESSING_RESOLUTION(PROCESSING_RESOLUTION)
    ) diff_stage(
        .clock(clock),
        .reset(reset),
        .samplink_clock(output_clock),
        .data_in(integration_out),
        .data_out(differentiation_out),
        .data_valid(differentiation_valid)
    );

    // OUTPUT STAGE
    reg output_clock_del = 0;
    reg [RESULT_RESOLUTION:0] unsigned_out = 0;
    reg [RESULT_RESOLUTION-1:0] adc_data = 0;

    reg output_valid = 0;
    reg [3:0] output_ctr= 0;

    always_comb begin
        if(unsigned_out[RESULT_RESOLUTION])begin
            adc_data <= {RESULT_RESOLUTION-1{1'b1}};
        end else begin
            adc_data <= unsigned_out - (1<<(RESULT_RESOLUTION-1));
        end

    end

    wire signed [RESULT_RESOLUTION-1:0] extended_data;
    assign extended_data = {{OUTPUT_SIZE-RESULT_RESOLUTION{adc_data[RESULT_RESOLUTION-1]}},adc_data};

    always @(posedge clock) begin
        if(~reset)begin
            output_valid <= 0;
        end else begin
            if(differentiation_valid & ~output_valid)begin
                if(output_clock & ~output_clock_del)begin
                    if(output_ctr == OUTPUT_VALID_DELAY-1)begin
                        output_valid <= 1;
                    end else begin
                        output_ctr <= output_ctr + 1;
                    end
                end
            end else begin
                output_ctr <= 0;
            end
        end


        data_out.user <= get_axis_metadata(RESULT_RESOLUTION, 1, 0);
        data_out.valid <= 0;
        output_clock_del <= output_clock;
        if(output_clock & ~output_clock_del) begin
            unsigned_out <= differentiation_out >> OUTPUT_SHIFT_SIZE;
        end

        if(sync & output_valid)begin
            data_out.data <= extended_data + offset;
            data_out.valid <= 1;
            data_out.dest <= CHANNEL_INDICATOR;
        end
    end

endmodule