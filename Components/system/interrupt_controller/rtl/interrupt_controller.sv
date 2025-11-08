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



    reg [N_INTERRUPTS-1:0] status_register = 0;
    reg [N_INTERRUPTS-1:0] ack_register;

    reg ack_trigger;
    axil_simple_register_cu #(
        .N_READ_REGISTERS(1),
        .N_WRITE_REGISTERS(1),
        .N_TRIGGER_REGISTERS(1),
        .TRIGGER_REGISTERS_IDX('{0}),
        .REGISTERS_WIDTH(32),
        .ADDRESS_MASK('hf)
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers('{status_register}),
        .output_registers('{ack_register}),
        .trigger_out('{ack_trigger}),
        .axil(axi_in)
    );



    always_ff @( posedge clock ) begin
        irq <= |status_register;
        
        if(ack_trigger)begin
            status_register <= status_register & ~ack_register;
        end else if(|interrupt_in)begin
            status_register <= status_register | interrupt_in;
        end
    end


endmodule
