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

`timescale 10ns / 1ns
`include "interfaces.svh"



module simplebus_rom #(
    parameter BASE_ADDRESS = 'h43c00000
)(
    input wire clock,
    input wire reset,
    Simplebus.slave sb
);


    reg read_data_blanking;
    reg [31:0] ram[14:0] = '{15,14,13,12,11,10,9,8,7,6,5,4,3,2,1};
    reg [31:0] int_readdata;

    // Port A 
    always @ (posedge clock) begin
        int_readdata <= ram[sb.sb_address-BASE_ADDRESS];
    end 


    always_comb begin
        if(~reset) begin
            sb.sb_read_data <=0;
        end else begin
            if(read_data_blanking) begin
                sb.sb_read_data <= 0;
            end else begin
                sb.sb_read_data <=int_readdata;
            end
        end
    end


    always @ (posedge clock) begin
        if(sb.sb_read_strobe)begin
            sb.sb_ready <= 0;
            read_data_blanking <= 0;
        end else begin
            sb.sb_ready <= 1;
            read_data_blanking <= 1;
        end
    end

endmodule