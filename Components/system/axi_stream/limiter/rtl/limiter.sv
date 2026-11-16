
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


module axis_limiter #(parameter BASE_ADDRESS = 'h43c00000)(
    input wire        clock,
    input wire        reset,
    axi_stream.master in,
    axi_stream.master out,
    axi_lite.slave axi_in
);

    typedef struct {
        reg [31:0] limit_up;
        reg [31:0] limit_down;
    } axis_limiter_registers;
    
    axis_limiter_registers registers;

    axil_simple_register_cu #(
        .READ_TYPE(axis_limiter_registers),
        .WRITE_TYPE(axis_limiter_registers),
        .REGISTERS_WIDTH(32),
        .ADDRESS_MASK('hf),
        .INITIAL_OUTPUT_VALUES('{limit_down: 32'h0,limit_up: 32'hffffffff})
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(registers),
        .output_registers(registers),
        .axil(axi_in)
    );


    assign in.ready = out.ready; 

    always_ff@(posedge clock)begin
        if(~reset)begin
            out.valid <= 0;
            out.data <= 0;
            out.dest <= 0;
        end else begin
            if(out.ready & in.valid) begin
                if(in.data > registers.limit_up)
                    out.data <= registers.limit_up;
                else if(in.data < registers.limit_down)
                    out.data <= registers.limit_down;
                else
                    out.data <= in.data;
                out.dest <= in.dest;
                out.valid <= 1;
                out.user <= in.user;
                out.tlast <= in.tlast;
            end else
                out.valid <= 0;
        end
    end

endmodule

    /**
       {
        "name": "axis_constant",
        "type": "parametric_peripheral",
        "registers":[
            {
                "name": "lim_up",
                "n_regs": ["1"],
                "description": "Highest allowable value on the stream",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "high",
                "n_regs": ["1"],
                "description": "Lowest allowable value on the stream",
                "direction": "RW",
                "fields":[]
            }
        ]
    }  
    **/