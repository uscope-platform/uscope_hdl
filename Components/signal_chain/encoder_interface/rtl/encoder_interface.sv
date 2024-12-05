// Copyright 2024 Filippo Savi
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
`include "interfaces.svh"

module encoder_interface (
    input wire clock,
    input wire reset,
    input wire a,
    input wire b,
    input wire z,
    input wire sample_angle,
    input wire sample_speed,
    axi_lite.slave axi_in,
    axi_stream.master angle,
    axi_stream.master speed
);



    reg [31:0] cu_read_registers [3:0];
    reg [31:0] cu_write_registers [3:0];
    
    axil_simple_register_cu #(
        .N_READ_REGISTERS(5),
        .N_WRITE_REGISTERS(5),
        .ADDRESS_MASK('h0FF)
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(cu_read_registers),
        .output_registers(cu_write_registers),
        .trigger_out(tap_write),
        .axil(axi_in)
    );

    wire [31:0] angle_out, speed_out;

    assign cu_read_registers[2:0] = cu_write_registers[2:0];

    assign cu_read_registers[3] = angle_out;
    assign cu_read_registers[4] = speed_out;
    wire [31:0] angle_dest;
    wire [31:0] speed_dest;
    wire [23:0] max_count;
    
    
    assign angle_dest = cu_write_registers[0];
    assign speed_dest = cu_write_registers[1];
    assign max_count = cu_write_registers[2];


    angle_sensing angle_measurement(
        .clock(clock),
        .reset(reset),
        .output_destination(angle_dest),
        .max_count(max_count),
        .a(a),
        .b(b),
        .z(z),
        .sample(sample_angle),
        .angle(angle),
        .angle_out(angle_out)
    );
    

    speed_sensing speed_measurement(
        .clock(clock),
        .reset(reset),
        .output_destination(speed_dest),
        .z(z),
        .sample(sample_speed),
        .speed(speed),
        .speed_out(speed_out)
    );

endmodule
