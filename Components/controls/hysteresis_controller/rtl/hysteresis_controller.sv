// Copyright 2026 Filippo Savi
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

module hysteresis_controller #(
    parameter SIGNED_INPUT = "FALSE"
)(
    input wire clock,
    input wire reset,
    input wire enable,
    axi_stream.slave in,
    output reg control_out,
    axi_lite.slave axi_in
);

    localparam N_REGISTERS = 2;

    wire [in.DATA_WIDTH-1:0] cu_registers [N_REGISTERS-1:0];


    axil_simple_register_cu #(
        .N_READ_REGISTERS(N_REGISTERS),
        .N_WRITE_REGISTERS(N_REGISTERS),
        .REGISTERS_WIDTH(32),
        .ADDRESS_MASK('hff)
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(cu_registers),
        .output_registers(cu_registers),
        .axil(axi_in)
    );

    wire [in.DATA_WIDTH-1:0] tresh_low;
    wire [in.DATA_WIDTH-1:0] tresh_high;

    wire signed [in.DATA_WIDTH-1:0] signed_tresh_low;
    wire signed [in.DATA_WIDTH-1:0] signed_tresh_high;

    assign tresh_low = cu_registers[0];
    assign tresh_high = cu_registers[1];

    assign signed_tresh_low = $signed(cu_registers[0]);
    assign signed_tresh_high = $signed(cu_registers[1]);

    wire signed [in.DATA_WIDTH-1:0] signed_in;
    assign signed_in = $signed(in.data);


    initial begin
        in.ready = 1;
        control_out = 0;
    end

    wire compare;
    assign compare = enable & in.valid;

    always_ff @( posedge clock ) begin
        if(enable & in.valid) begin
            if(SIGNED_INPUT=="TRUE")begin
                 if(control_out)begin
                    control_out <= signed_in < signed_tresh_low;
                end else begin
                    control_out <= signed_in > signed_tresh_high;
                end
            end else begin
                if(control_out)begin
                    control_out <= in.data < tresh_low;
                end else begin
                    control_out <= in.data > tresh_high;
                end
            end
        end
    end

endmodule
   
    /**
       {
        "name": "hysteresis_controller",
        "type": "parametric_peripheral",
        "registers":[
            {
                "name": "tresh_low",
                "n_regs": ["1"],
                "description": "Low bound treshold",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "tresh_high",
                "n_regs": ["1"],
                "description": "High bound treshold",
                "direction": "RW",
                "fields":[]
            }
        ]
       }  
    **/