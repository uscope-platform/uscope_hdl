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

module gpio #(
    parameter BASE_ADDRESS = 0,
    INPUT_WIDTH = 8,
    OUTPUT_WIDTH = 8
)(
    input wire clock,
    input wire reset,
    input wire [INPUT_WIDTH-1:0] gpio_i,
    output reg [OUTPUT_WIDTH-1:0] gpio_o,
    axi_lite.slave axil
);

    typedef struct {
            reg [31:0] out;
            reg [31:0] in;
    } gpio_registers;
        
    gpio_registers read_registers, write_registers;

    always_comb begin
        read_registers = write_registers;
        read_registers.in = 32'(gpio_i);
        gpio_o = write_registers.out[OUTPUT_WIDTH-1:0];
    end

    axil_simple_register_cu #(
        .READ_TYPE(gpio_registers),
        .WRITE_TYPE(gpio_registers),
        .ADDRESS_MASK('hf)
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(read_registers),
        .output_registers(write_registers),
        .axil(axil)
    );


endmodule
   
    /**
       {
        "name": "gpio",
        "type": "parametric_peripheral",
        "registers":[
            {
                "name": "out",
                "n_regs": ["1"],
                "description": "Output Register",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "in",
                "n_regs": ["1"],
                "description": "Input Register",
                "direction": "R",
                "fields":[]
            }
        ]
       }  
    **/