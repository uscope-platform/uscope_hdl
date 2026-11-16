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
    input wire enable,
    input wire [N_FAULTS-1:0] fault_in,
    output reg fault_out,
    output reg clear_fault,
    axi_lite.slave axi_in
);




    typedef struct {
        reg [31:0] exclusions;
        reg [31:0] rsvd_1;
        reg [31:0] clear;
    } axis_limiter_write_registers;

    typedef struct {
        reg [31:0] exclusions;
        reg [31:0] fault_in;      
        reg [31:0] clear;  
    } axis_limiter_read_registers;
    
    axis_limiter_write_registers write_registers;
    axis_limiter_read_registers read_registers;


    axil_simple_register_cu #(
        .READ_TYPE(axis_limiter_read_registers),
        .WRITE_TYPE(axis_limiter_write_registers),
        .REGISTERS_WIDTH(32),
        .ADDRESS_MASK('hf),
        .TRIGGER_MASK('{clear:1, default:0})
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(read_registers),
        .output_registers(write_registers),
        .trigger_out(clear_fault),
        .axil(axi_in)
    );

    always_comb begin 
        read_registers.exclusions = write_registers.exclusions;
        read_registers.fault_in = fault_in;
        read_registers.clear = write_registers.clear;
    end


    reg internal_fault;

    always_ff @(posedge clock)begin
        fault_out <= internal_fault;
    end

    always_latch begin
    if(clear_fault | ~reset | ~enable)begin
            internal_fault <= 0;
        end else if (~internal_fault)begin
            internal_fault <= |(fault_in & ~write_registers.exclusions);
        end
    end

endmodule
