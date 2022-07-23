// Copyright 2021 Filippo Savi
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

`timescale 10ns / 1ns
`include "interfaces.svh"

module merging_core #(
    parameter DATA_WIDTH=32
)(
    input wire clock,
    input wire reset,
    axi_stream.slave stream_in_a,
    axi_stream.slave stream_in_b,
    axi_stream.master merged_stream
);

    reg merge_in_progress = 0;

    always_ff @(posedge clock) begin
        merged_stream.valid <= 0; 
        merged_stream.data <= 0;
        if(stream_in_a.valid & stream_in_b.valid)begin
            merge_in_progress <= 1;
        end
        if(merge_in_progress)begin
            if(stream_in_a.data > stream_in_b.data) begin
                if(stream_in_b.valid)
                    merged_stream.data <= stream_in_b.data;
                else
                    merged_stream.data <= stream_in_a.data;
            end else begin
                if(stream_in_a.valid)
                    merged_stream.data <= stream_in_a.data;
                else
                    merged_stream.data <= stream_in_b.data;
            end
            if(~(stream_in_a.valid | stream_in_b.valid)) begin
                merge_in_progress <= 0;
            end
            merged_stream.valid <= stream_in_a.valid | stream_in_b.valid;
        end
    end


    assign stream_in_a.ready = merge_in_progress & (stream_in_a.data < stream_in_b.data) | ~stream_in_b.valid;
    assign stream_in_b.ready = merge_in_progress & (stream_in_a.data > stream_in_b.data) | ~stream_in_a.valid;



endmodule