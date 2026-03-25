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
`timescale 10ns / 1ns

module fault_management_unit #(
    int N_FAULTS = 6
)(
    input wire clock,
    input wire reset,
    input wire [N_FAULTS-1:0] fault_in,
    output reg fault_out,
    output reg clear_fault,
    axi_lite.slave axi_in
);


    localparam N_REGISTERS = 3;

    wire [31:0] cu_write_registers [N_REGISTERS-1:0];
    wire [31:0] cu_read_registers [N_REGISTERS-1:0];

    axil_simple_register_cu #(
        .N_READ_REGISTERS(N_REGISTERS),
        .N_WRITE_REGISTERS(N_REGISTERS),
        .REGISTERS_WIDTH(32),
        .TRIGGER_REGISTERS_IDX('{2}),
        .TRIGGER_REGISTERS_IDX(1),
        .ADDRESS_MASK('hff)
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(cu_read_registers),
        .output_registers(cu_write_registers),
        .axil(axi_in),
        .trigger_out(clear_fault)
    );


    wire [N_FAULTS-1:0] exclusions;
    assign exclusions = cu_write_registers[0];


    assign cu_read_registers[0] = exclusions;
    assign cu_read_registers[1] = fault_in;

    always_ff @(posedge clock)begin
        fault_out <= |(fault_in & ~exclusions);
    end



endmodule
