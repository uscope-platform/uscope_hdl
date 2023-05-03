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

module fir_filter_parallel #(
    parameter DATA_PATH_WIDTH = 16,
    TAP_WIDTH = 16,
    WORKING_WIDTH = DATA_PATH_WIDTH > TAP_WIDTH ? DATA_PATH_WIDTH : TAP_WIDTH,
    PARALLEL_ORDER=8,
    parameter [WORKING_WIDTH-1:0] TAPS_IV [PARALLEL_ORDER:0] = '{PARALLEL_ORDER+1{0}}
)(
    input wire clock,
    input wire reset,
    input wire [WORKING_WIDTH-1:0] tap_data,
    input wire [15:0] tap_addr,
    input wire tap_write,
    axi_stream.slave data_in,
    axi_stream.master data_out
);
    
    reg [WORKING_WIDTH-1:0] taps [PARALLEL_ORDER:0] = TAPS_IV; 

    always_ff@(posedge clock) begin
        if(tap_write)begin
            if(DATA_PATH_WIDTH>TAP_WIDTH)begin
                taps[tap_addr] <= tap_data<<(DATA_PATH_WIDTH-TAP_WIDTH);
            end else begin
                taps[tap_addr] <= tap_data;
            end
        end
    end

    wire [WORKING_WIDTH-1:0] scaled_data_in;

    generate

        if(TAP_WIDTH>DATA_PATH_WIDTH)begin
            assign scaled_data_in = data_in.data<<(TAP_WIDTH-DATA_PATH_WIDTH);
        end else begin
            assign scaled_data_in = data_in.data;
        end

    endgenerate



    wire [2*WORKING_WIDTH-1:0] pipeline_inputs [PARALLEL_ORDER-1:0];
    reg signed [2*WORKING_WIDTH-1:0] pipeline_registers [PARALLEL_ORDER-1:0];

    assign data_in.ready = data_out.ready;

    genvar i;
    generate
        
        assign pipeline_inputs[0] = 0;
        for(i = 1; i<PARALLEL_ORDER; i++)begin
            assign pipeline_inputs[i] = pipeline_registers[i-1];
        end

        if(DATA_PATH_WIDTH>=TAP_WIDTH)
            assign data_out.data = pipeline_registers[PARALLEL_ORDER-1]>>>(WORKING_WIDTH-1);
        else
            assign data_out.data = pipeline_registers[PARALLEL_ORDER-1]>>>(WORKING_WIDTH-1+TAP_WIDTH-DATA_PATH_WIDTH);
        for(i = 0; i<PARALLEL_ORDER+1; i++)begin

            fir_filter_slice #(
                .DATA_PATH_WIDTH(WORKING_WIDTH),
                .TAP_WIDTH(WORKING_WIDTH)
            ) filter_stage (
                .clock(clock),
                .data_in($signed(scaled_data_in)),
                .in_valid(data_in.valid),
                .tap(taps[i]),
                .pipeline_in(pipeline_inputs[i]),
                .pipeline_out(pipeline_registers[i]),
                .out_valid(data_out.valid)
            );
        end
    endgenerate

endmodule