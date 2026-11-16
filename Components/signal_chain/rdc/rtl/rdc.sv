// Copyright 2023 Filippo Savi
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

module rdc #(
)(
    input wire clock,
    input wire reset,
    output reg excitation,
    axi_stream.slave analog_in,
    axi_stream.slave angle,
    axi_stream.slave control
);


    typedef struct packed {
        reg [31:0] offset;
        reg [31:0] dds_divider;
        reg [31:0] modulator_divider;
    } rdc_registers_t;

    rdc_registers_t regs;
    
    localparam N_REGISTERS = 3;
    reg [31:0] cu_write_registers [N_REGISTERS-1:0];
    reg [31:0] cu_read_registers  [N_REGISTERS-1:0];


    axil_simple_register_cu #(
        .N_READ_REGISTERS(N_REGISTERS),
        .N_WRITE_REGISTERS(N_REGISTERS),
        .REGISTERS_WIDTH(32),
        .ADDRESS_MASK('hff)
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(cu_read_registers),
        .output_registers(cu_write_registers),
        .axil(control)
    );





    reg [7:0] trg_counter = 0;
    reg dds_trigger;
    reg mod_trigger = 0;
    
    always_ff @(posedge clock)begin
        
        if(trg_counter == 2)begin
            trg_counter <= 0;
            dds_trigger <= 1;
        end else begin
            dds_trigger <= 0;
            trg_counter <= trg_counter +1;
        end
        mod_trigger <= ~mod_trigger;
    end


    axi_stream #(.DATA_WIDTH(16)) excitation_sine();

    reg [31:0] dds_parameters [15:0] = '{default:0};

    sine_core dds (
        .clock(clock),
        .reset(reset),
        .trigger(dds_trigger),
        .parameters(dds_parameters),
        .data_out(excitation_sine)
    );


    sigma_delta_modulator #(
        .GUARD_BITS(18)
    ) dac_core (
        .clock(clock),
        .reset(reset),
        .modulator_clock(mod_trigger),
        .data_out(excitation),
        .data_in(excitation_sine)
    );

    axi_stream #(.DATA_WIDTH(16)) sin();
    axi_stream #(.DATA_WIDTH(16)) cos();
    axi_stream #(.DATA_WIDTH(16)) raw_angle();
    
    product_detector detector (
        .clock(clock),
        .reset(reset),
        .analog_in(analog_in),
        .excitation(excitation_sine),
        .sin(sin),
        .cos(cos)
    );


    CORDIC_atan #(
        .RESOLUTION(16),
        .OUTPUT_0_2PI(1)
    )atan(
        .clock(clock),
        .reset(reset),
        .x(sin), 
        .y(cos),
        .out(raw_angle)
    );

    assign raw_angle.ready = 1;
    
endmodule