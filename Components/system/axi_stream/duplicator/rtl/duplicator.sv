
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


module axis_duplicator #(
    parameter buffer="FALSE"
) (
    input wire clock,
    axi_stream.slave in,
    axi_stream.master out_1,
    axi_stream.master out_2
);


    generate
        if(buffer == "TRUE")begin
            always_ff @(posedge clock ) begin
                out_1.data <= in.data;
                out_1.dest <= in.dest;
                out_1.user <= in.user;
                out_1.valid <= in.valid;
                out_1.tlast <= in.tlast;
                

                out_2.data <= in.data;
                out_2.dest <= in.dest;
                out_2.user <= in.user;
                out_2.valid <= in.valid;
                out_2.tlast <= in.tlast;    
            end

            assign in.ready = out_1.ready;
        end else begin
            assign out_1.data = in.data;
            assign out_1.dest = in.dest;
            assign out_1.user = in.user;
            assign out_1.valid = in.valid;
            assign out_1.tlast = in.tlast;
            assign in.ready = out_1.ready;

            assign out_2.data = in.data;
            assign out_2.dest = in.dest;
            assign out_2.user = in.user;
            assign out_2.valid = in.valid;
            assign out_2.tlast = in.tlast;
        end
    endgenerate
        
endmodule
