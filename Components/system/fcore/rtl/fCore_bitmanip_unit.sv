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
import fcore_isa::*;

module fCore_bitmanip_unit (
    input wire clock,
    input wire reset,
    axi_stream.slave operand_a,
    axi_stream.slave operand_b,
    axi_stream.slave operand_c,
    axi_stream.slave operation,
    axi_stream.master result 
);




    reg [7:0] ones = 0;
    always@(posedge clock) begin
        result.valid <= 0;
        result.user <= 0;
        result.data <= 0;
        if(operand_a.valid)begin
            case(operation.data)
                3:begin
                    ones = 0;
                    foreach(operand_a.data[idx]) begin
                        ones += operand_a.data[idx];
                    end
                    result.valid <= 1;
                    result.user <= operand_a.user;
                    result.data <= ones;  
                end
                5:begin
                    result.valid <= 1;
                    result.user <= operand_a.user;
                    result.data <= operand_a.data[31:0];
                    result.data <= operand_a.data[operand_b.data];  
                end
                7:begin
                    result.valid <= 1;
                    result.user <= operand_a.user;
                    result.data <= operand_a.data[31:0];
                    result.data[operand_b.data] <= operand_c.data;
                end
            endcase
        end
    end

endmodule