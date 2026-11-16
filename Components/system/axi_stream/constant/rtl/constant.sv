
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


module axis_constant #(
    parameter PRAGMA_MKFG_PROXY = "FALSE",
    parameter PRAGMA_MKFG_PROXY_TL = "",
    parameter PRAGMA_MKFG_PROXY_IF = "proxy_if"
)(
    input wire        clock,
    input wire        reset,
    input wire        sync,
    axi_stream.master const_out,
    axi_lite.slave axil
);

    wire trigger_axis_write;

    typedef struct {
        reg [31:0] low_bytes;
        reg [31:0] high_bytes;
        reg [31:0] constant_dest;
    } axis_constant_registers;
    
    axis_constant_registers registers;

    axil_simple_register_cu #(
        .READ_TYPE(axis_constant_registers),
        .WRITE_TYPE(axis_constant_registers),
        .ADDRESS_MASK('hf),
        .TRIGGER_MASK('{low_bytes:1, default:0})
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(registers),
        .output_registers(registers),
        .trigger_out(trigger_axis_write),
        .axil(axil)
    );

    reg wait_sync;

    always_ff @(posedge clock) begin
        if (~reset) begin
            const_out.valid <= 0;
            const_out.data <= 0;
            const_out.dest <= 0;
            wait_sync <= 0;
        end else begin
            const_out.valid <= 0;
            if(trigger_axis_write)begin
                if(const_out.ready & sync) begin
                    const_out.data <= {registers.high_bytes, registers.low_bytes};
                    const_out.dest <= registers.constant_dest;
                    const_out.valid <= 1;
                end else begin
                    wait_sync = 1;
                end   
            end else if(wait_sync) begin
                if(const_out.ready & sync) begin
                    const_out.data <= {registers.high_bytes, registers.low_bytes};
                    const_out.dest <= registers.constant_dest;
                    const_out.valid <= 1;
                    wait_sync <= 0;
                end              
            end
        end
    end



endmodule


    /**
       {
        "name": "axis_constant",
        "type": "parametric_peripheral",
        "registers":[
            {
                "name": "low",
                "n_regs": ["1"],
                "description": "Least significant bytes of the constant",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "high",
                "n_regs": ["1"],
                "description": "Most significant bytes of the constant",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "dest",
                "n_regs": ["1"],
                "description": "Value of the AXI stream dest signal associated with the constant",
                "direction": "RW",
                "fields":[]
                
            }
        ]
    }  
    **/
