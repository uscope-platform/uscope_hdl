
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


module axis_decoupler #(
    parameter REMAP="FALSE", 
    REMAP_OFFSET = 0
    ) (
    axi_stream.slave in,
    axi_stream.master out
);


    assign out.data = in.data;

    generate
        if(REMAP == "TRUE")begin
            assign out.dest = in.dest+REMAP_OFFSET;
        end else begin
            assign out.dest = in.dest;
        end
    endgenerate
    
    assign out.user = in.user;
    assign out.valid = in.valid;
    assign out.tlast = in.tlast;
    
endmodule
