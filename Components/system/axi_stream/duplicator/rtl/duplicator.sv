
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

module axis_duplicator #(
    parameter buffer="FALSE",
    parameter N_OUTPUTS = 2
) (
    input wire clock,
    axi_stream.slave in,
    axi_stream.master out[N_OUTPUTS]
);

    genvar i;
    assign in.ready = out[0].ready;

    generate
        if(buffer == "TRUE")begin
           
           for(i = 0; i<N_OUTPUTS; i++) begin
                always_ff @(posedge clock ) begin
                    out[i].data <= in.data;
                    out[i].dest <= in.dest;
                    out[i].user <= in.user;
                    out[i].valid <= in.valid;
                    out[i].tlast <= in.tlast;
                end  
            end

        end else begin
            for(i = 0; i<N_OUTPUTS; i++) begin
                always_comb begin
                    out[i].data <= in.data;
                    out[i].dest <= in.dest;
                    out[i].user <= in.user;
                    out[i].valid <= in.valid;
                    out[i].tlast <= in.tlast;
                end  
            end


        end
    endgenerate
        
endmodule
