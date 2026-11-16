// Copyright 2025 Filippo Savi
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
`timescale 1 ns / 100 ps

module interrupt_controller # (
    parameter integer N_INTERRUPTS = 1
)(
    input wire clock,
    input wire reset,
    input wire [N_INTERRUPTS-1:0] interrupt_in,
    output reg irq,
    axi_lite.slave axi_in
);


    reg ack_trigger;

    typedef struct {
        reg [31:0] status;
    } interrupt_controller_read_registers;

    typedef struct {
        reg [31:0] ack;
    } interrupt_controller_write_registers;
    
    interrupt_controller_read_registers read_registers;
    interrupt_controller_write_registers write_registers;


    axil_simple_register_cu #(
        .READ_TYPE(interrupt_controller_read_registers),
        .WRITE_TYPE(interrupt_controller_write_registers),
        .REGISTERS_WIDTH(32),
        .ADDRESS_MASK('hff),
        .TRIGGER_MASK('{ack: 1})
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(read_registers),
        .output_registers(write_registers),
        .trigger_out('{ack_trigger}),
        .axil(axi_in)
    );

    initial begin
        read_registers.status  = 0;
    end


    always_ff @( posedge clock ) begin
        irq <= |read_registers.status;
        
        if(ack_trigger)begin
            read_registers.status <= read_registers.status & ~write_registers.ack;
        end else if(|interrupt_in)begin
            read_registers.status <= read_registers.status | interrupt_in;
        end
    end


endmodule
