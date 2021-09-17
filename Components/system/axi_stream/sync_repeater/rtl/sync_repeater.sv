

// Copyright 2021 University of Nottingham Ningbo China
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


module axis_sync_repeater #(parameter DATA_WIDTH= 32, DEST_WIDTH = 8, USER_WIDTH = 8)(
    input wire        clock,
    input wire        reset,
    input wire        sync,
    axi_stream.slave in,
    axi_stream.master out
);


    reg [DATA_WIDTH-1:0] latched_data;
    reg [DEST_WIDTH-1:0] latched_dest;
    reg [USER_WIDTH-1:0] latched_user;
    reg latched_tlast;

    always_ff@(posedge clock)begin
        if(~reset)begin
            out.valid <= 0;
            out.data <= 0;
            out.dest <= 0;
            latched_data <= 0;
            latched_dest <= 0;
            latched_user <= 0;
            latched_tlast <= 0;
        end else begin
            out.valid <= 0;
            if(in.valid)begin
                latched_data <= in.data;
                latched_dest <= in.dest;
                latched_user <= in.user;
                latched_tlast <= in.tlast; 
            end
            if(sync)begin
                out.data <= latched_data;
                out.dest <= latched_dest;
                out.user <= latched_user;
                out.tlast <= latched_tlast;
                out.valid <= 1;
            end
        end
    end

endmodule