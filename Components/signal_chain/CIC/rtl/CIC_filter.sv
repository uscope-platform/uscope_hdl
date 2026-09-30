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
`include "helpers.svh"

module CIC_filter #(
    parameter integer N_STAGES = 3,
    parameter integer MAX_RATIO = 32,
    parameter integer RATIO_WIDTH = $clog2(MAX_RATIO)
)(
    input wire clock,
    input wire reset,
    input wire [RATIO_WIDTH-1:0] downsampling_ratio,
    axi_stream.slave data_in,
    axi_stream.master data_out
);
    
    localparam integer PROCESSING_RESOLUTION = $bits(data_in.data)+ $clog2( 64'(MAX_RATIO) ** N_STAGES );


    axi_stream #(
        .DATA_WIDTH(data_in.DATA_WIDTH),
        .USER_WIDTH(data_in.USER_WIDTH),
        .DEST_WIDTH(data_in.DEST_WIDTH)
    ) data_in_buf();

    axis_skid_buffer #(
        .REGISTER_OUTPUT(0),
        .LATCHING(0)
    ) in_skid (
        .clock(clock),
        .reset(reset),
        .axis_in(data_in),
        .axis_out(data_in_buf)
    );

    assign data_in_buf.ready = data_out.ready;

    reg [PROCESSING_RESOLUTION-1:0] integrator_out [N_STAGES-1:0];
    reg [PROCESSING_RESOLUTION-1:0] comb_out [N_STAGES-1:0];

    integrator_stage #(
            .PROCESSING_RESOLUTION(PROCESSING_RESOLUTION)
    )integrator_0(
        .clock(clock),
        .reset(reset),
        .data_clock(data_in_buf.valid),
        .data_in(PROCESSING_RESOLUTION'($signed(data_in_buf.data))),
        .data_out(integrator_out[0])
    );


    comb_stage #(
        .PROCESSING_RESOLUTION(PROCESSING_RESOLUTION)
    ) comb_0 (
        .clock(clock),
        .reset(reset),
        .data_clock(comb_clock),
        .data_in(integrator_out[N_STAGES-1]),
        .data_out(comb_out[0])
    );

    genvar i;
    generate
        for(i = 1; i< N_STAGES; i++)begin

                    
            integrator_stage #(
                    .PROCESSING_RESOLUTION(PROCESSING_RESOLUTION)
            )integrator(
                .clock(clock),
                .reset(reset),
                .data_clock(data_in_buf.valid),
                .data_in(integrator_out[i-1]),
                .data_out(integrator_out[i])
            );


            comb_stage #(
                    .PROCESSING_RESOLUTION(PROCESSING_RESOLUTION)
            )comb(
                .clock(clock),
                .reset(reset),
                .data_clock(comb_clock),
                .data_in(comb_out[i-1]),
                .data_out(comb_out[i])
            );

        end
    endgenerate
    wire [$bits(data_out.data)-1:0] sized_out;

    generate
        if($bits(data_out.data)==PROCESSING_RESOLUTION) 
            assign sized_out = comb_out[N_STAGES-1];
        else if($bits(data_out.data)>PROCESSING_RESOLUTION)
            assign sized_out = $signed(comb_out[N_STAGES-1]);
        else
            assign sized_out = comb_out[N_STAGES-1][PROCESSING_RESOLUTION-1:PROCESSING_RESOLUTION-$bits(data_out.data)];
    endgenerate

    reg [RATIO_WIDTH-1:0] downsampling_ctr = 0;
    reg comb_clock = 0;
    reg out_phase = 0;
    reg pipeline_full = 0;
    reg [$clog2(N_STAGES)-1:0] fill_ctr = 0;
    always_ff @(posedge clock)begin
        data_out.valid <= 0;
        comb_clock<= 0;
        out_phase <= comb_clock;
        if(data_in_buf.valid)begin
            if(downsampling_ctr == downsampling_ratio-1)begin
                comb_clock<= 1;
                if(fill_ctr == N_STAGES-1)begin
                    pipeline_full <= 1;
                end else begin
                    fill_ctr <= fill_ctr +1;
                end
                downsampling_ctr <= 0;
            end else  begin
                downsampling_ctr <= downsampling_ctr+1;
            end
        end

        if(out_phase && pipeline_full)begin
            data_out.data <= sized_out;
            data_out.valid <= 1;
        end

    end

endmodule