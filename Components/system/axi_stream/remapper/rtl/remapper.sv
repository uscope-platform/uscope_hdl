
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


module axis_remapper #(
    parameter DECOUPLE = "FALSE",
    REGISTER_OUT="FALSE",
    REMAP="FALSE", 
    REMAP_TYPE = "DYNAMIC",
    REMAP_OFFSET = 0,
    INPUT_DATA_WIDTH = 16,
    OUTPUT_DATA_WIDTH = 16
    ) (
    input wire clock,
    axi_stream.slave in,
    axi_stream.master out
);


    axi_stream #(.DATA_WIDTH(OUTPUT_DATA_WIDTH)) inner_out();

    generate
    
        if ((REMAP != "TRUE") && (REMAP != "FALSE")) begin
            $error($sformatf("Illegal value for parameter REMAP (%s), it must be either TRUE or FALSE",REMAP));
        end
    
        if ((REMAP_TYPE != "DYNAMIC") && (REMAP_TYPE != "STATIC")) begin
            $error($sformatf("Illegal value for parameter REMAP_TYPE (%s), it must be either STATIC or DYNAMIC",REMAP_TYPE));
        end

        if(REGISTER_OUT == "TRUE")begin
            always_ff @( posedge clock ) begin
                
                out.data <= inner_out.data;
                out.dest <= inner_out.dest;
                out.valid <= inner_out.valid;
                out.user <= inner_out.user;
                out.tlast <= inner_out.tlast;
            end
        end else begin
            assign out.data = inner_out.data;
            assign out.dest = inner_out.dest;
            assign out.valid = inner_out.valid;
            assign out.user = inner_out.user;
            assign out.tlast = inner_out.tlast;
        end


    
        if(OUTPUT_DATA_WIDTH>INPUT_DATA_WIDTH)begin
            assign inner_out.data = {{OUTPUT_DATA_WIDTH-INPUT_DATA_WIDTH{in.data[INPUT_DATA_WIDTH-1]}},in.data};
        end else begin
            assign inner_out.data = in.data;
        end


        if(REMAP == "TRUE")begin
            if(REMAP_TYPE == "DYNAMIC") begin 
                assign inner_out.dest = in.dest+REMAP_OFFSET;
            end else if(REMAP_TYPE == "STATIC") begin
                assign inner_out.dest = REMAP_OFFSET;
            end
        end else begin
            assign inner_out.dest = in.dest;
        end

        if(DECOUPLE == "FALSE") begin
            assign in.ready = out.ready;
        end
    endgenerate
    

    assign inner_out.user = in.user;
    assign inner_out.valid = in.valid;
    assign inner_out.tlast = in.tlast;
    
endmodule
