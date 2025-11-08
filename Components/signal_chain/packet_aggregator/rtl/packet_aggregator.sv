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

module packet_aggregator #(
    parameter DATA_PATH_WIDTH = 16,
    parameter PACKET_START_ADDR = 0,
    parameter PACKET_LENGHT = 10,
    parameter RESULT_DEST = 0,
    parameter RESULT_USER = 0
)(
    input wire clock,
    input wire reset,
    axi_stream.slave data_in,
    axi_stream.master data_out
);

reg [7:0] aggregation_count = 0;
reg [31:0] aggregated_value = 0;
reg aggregation_in_progress = 0;

always_ff @(posedge clock)begin
    if(~aggregation_in_progress)begin
        data_out.valid <= 0;
        data_out.data <= 0;
        data_out.dest <= RESULT_DEST;
        data_out.user <= RESULT_USER;
        if(data_in.valid & data_in.dest == PACKET_START_ADDR) begin
            aggregated_value <= data_in.data;
            aggregation_in_progress <= 1;
            aggregation_count <= aggregation_count + 1;
        end
    end else begin
        if(aggregation_count == PACKET_LENGHT-1)begin
            data_out.data <= aggregated_value + data_in.data;
            data_out.valid <= 1;
            aggregation_in_progress <= 0;
            aggregation_count <= 0;
        end else begin
            aggregated_value <= aggregated_value + data_in.data;
            aggregation_in_progress <= 1;
            aggregation_count <= aggregation_count + 1;
        end
    end
    

end

endmodule