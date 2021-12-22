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
`include "interfaces.svh"

module enable_generator_3 #(parameter BASE_ADDRESS = 0, COUNTER_WIDTH = 32)(
    input wire        clock,
    input wire        reset,
    input wire        gen_enable_in,
    output wire enable_out_1,
    output wire enable_out_2,
    output wire enable_out_3,
    axi_lite.slave axil
);

    reg [COUNTER_WIDTH-1:0] period;
    wire [COUNTER_WIDTH-1:0] count;

    reg bus_enable;
    
    reg [COUNTER_WIDTH-1:0] enable_threshold_1;
    reg [COUNTER_WIDTH-1:0] enable_threshold_2;
    reg [COUNTER_WIDTH-1:0] enable_threshold_3;



    reg [31:0] cu_write_registers [4:0];
    reg [31:0] cu_read_registers [4:0];

    localparam ADDITIONAL_BITS = 32 - COUNTER_WIDTH;

    axil_simple_register_cu #(
        .N_READ_REGISTERS(5),
        .N_WRITE_REGISTERS(5),
        .REGISTERS_WIDTH(32),
        .BASE_ADDRESS(BASE_ADDRESS)
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(cu_read_registers),
        .output_registers(cu_write_registers),
        .axil(axil)
    );


    always_comb begin 
        bus_enable <= cu_write_registers[0];
        period <= cu_write_registers[1];
        enable_threshold_1 <= cu_write_registers[2];
        enable_threshold_2 <= cu_write_registers[3];
        enable_threshold_3 <= cu_write_registers[4];
        cu_read_registers[0] <= {31'b0, {bus_enable}};
        cu_read_registers[1] <= {{ADDITIONAL_BITS{1'b0}},period};
        cu_read_registers[2] <= {{ADDITIONAL_BITS{1'b0}},enable_threshold_1};
        cu_read_registers[3] <= {{ADDITIONAL_BITS{1'b0}},enable_threshold_2};
        cu_read_registers[4] <= {{ADDITIONAL_BITS{1'b0}},enable_threshold_3};
    end

    enable_generator_counter counter(
        .clock(clock),
        .reset(reset),
        .gen_enable_in(bus_enable | gen_enable_in),
        .period(period),
        .counter_out(count)
    );
    
    defparam comparator_1.COUNTER_WIDTH = COUNTER_WIDTH;
    enable_comparator comparator_1(
        .clock(clock),
        .reset(reset),
        .enable_treshold(enable_threshold_1),
        .count(count),
        .enable_out(enable_out_1)
    );
    
    defparam comparator_2.COUNTER_WIDTH = COUNTER_WIDTH;
    enable_comparator comparator_2(
        .clock(clock),
        .reset(reset),
        .enable_treshold(enable_threshold_2),
        .count(count),
        .enable_out(enable_out_2)
    );
    
    defparam comparator_3.COUNTER_WIDTH = COUNTER_WIDTH;
    enable_comparator comparator_3(
        .clock(clock),
        .reset(reset),
        .enable_treshold(enable_threshold_3),
        .count(count),
        .enable_out(enable_out_3)
    );
    



endmodule