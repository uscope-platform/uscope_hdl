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

`timescale 10ns / 1ns
`include "interfaces.svh"

module waveform_generator #(
    parameter int N_OUTPUTS = 2
)(
    input wire clock,
    input wire reset,
    input wire trigger,
    output reg active,
    axi_lite.slave axi_in,
    axi_stream.master data_out
);

    localparam int N_PARAMETERS = 10;
    localparam int N_REGISTERS = N_PARAMETERS+3;

    reg [31:0] cu_read_registers [N_REGISTERS-1:0];
    reg [31:0] cu_write_registers [N_REGISTERS-1:0];

    wire latch_parameters;
    axil_simple_register_cu #(
        .N_READ_REGISTERS(N_REGISTERS),
        .N_WRITE_REGISTERS(N_REGISTERS),
        .ADDRESS_MASK('hFF),
        .TRIGGER_REGISTERS_IDX('{0}),
        .N_TRIGGER_REGISTERS(1)
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(cu_read_registers),
        .output_registers(cu_write_registers),
        .axil(axi_in),
        .trigger_out('{latch_parameters})
    );


    reg [1:0] shape [N_OUTPUTS];
    wire [15:0] active_channels;
    reg [31:0] parameters[N_OUTPUTS][N_PARAMETERS-1:0];
    wire [7:0] output_selector;
    assign cu_read_registers = cu_write_registers;

    assign active_channels = cu_write_registers[0];
    assign output_selector = cu_write_registers[2];



    axi_stream square_out[N_OUTPUTS]();
    axi_stream sine_out[N_OUTPUTS]();
    axi_stream triangle_out[N_OUTPUTS]();

    axi_stream channel_out [N_OUTPUTS]();

    initial active = 0;


    genvar output_idx;
    genvar i;
    generate
        for ( i = 0; i<N_PARAMETERS; i++) begin
            always_ff @(posedge clock)begin
                if(latch_parameters)begin
                    parameters[output_selector][i] <= cu_write_registers[i+3];
                    shape[output_selector] <= cu_write_registers[1][1:0];
                    active <= 1;
                end
            end
        end

        for (output_idx = 0; output_idx<N_OUTPUTS; output_idx++) begin

            square_core #(
                .N_PARAMETERS(N_PARAMETERS)
            )square_gen(
                .clock(clock),
                .reset(reset),
                .trigger(trigger & active_channels>output_idx),
                .parameters(parameters[output_idx]),
                .data_out(square_out[output_idx])
            );

            sine_core #(
                .N_PARAMETERS(N_PARAMETERS)
            )sine_gen(
                .clock(clock),
                .reset(reset),
                .trigger(trigger),
                .parameters(parameters[output_idx]),
                .data_out(sine_out[output_idx])
            );

            triangle_core #(
                .N_PARAMETERS(N_PARAMETERS)
            )triangle_gen(
                .clock(clock),
                .reset(reset),
                .trigger(trigger & active_channels>output_idx),
                .parameters(parameters[output_idx]),
                .data_out(triangle_out[output_idx])
            );

            axi_stream_mux #(
                .N_STREAMS(3),
                .DATA_WIDTH(32),
                .DEST_WIDTH(32),
                .USER_WIDTH(32),
                .BUFFERED(0)
            ) output_selection (
                .clock(clock),
                .reset(reset),
                .address(shape[output_idx]),
                .stream_in('{square_out[output_idx], sine_out[output_idx], triangle_out[output_idx]}),
                .stream_out(channel_out[output_idx])
            );
        end

    endgenerate

    axi_stream serialized_out();

    axi_stream_combiner #(
        .INPUT_DATA_WIDTH(32),
        .OUTPUT_DATA_WIDTH(32),
        .DEST_WIDTH(32),
        .USER_WIDTH(32),
        .N_STREAMS(N_OUTPUTS)
    ) UUT (
        .clock(clock),
        .reset(reset),
        .stream_in(channel_out),
        .stream_out(serialized_out)
    );


    assign serialized_out.ready = data_out.ready;

    reg [15:0] tlast_counter = 0;

    always_ff @( posedge clock ) begin
        data_out.data <= serialized_out.data;
        data_out.valid <= serialized_out.valid;
        data_out.dest <= serialized_out.dest;
        data_out.user <= serialized_out.user;

        if(serialized_out.valid == 0) begin
            data_out.tlast <= 0;
        end else begin
            if(tlast_counter == active_channels-1) begin
                data_out.tlast <= 1;
            end else begin
                tlast_counter <= tlast_counter+1;
            end
        end
    end

endmodule

 /**
    {
        "name": "waveform_generator",
        "alias": "waveform_generator",
        "type": "parametric_peripheral",
        "registers":[
            {
                "name": "enable",
                "n_regs": ["1"],
                "description": "Write 1 to a bit in this register to enable the corresponding channel",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "shape",
                "n_regs": ["1"],
                "description": "Shape of the selected channel",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "output_selector",
                "n_regs": ["1"],
                "description": "Select the output parameter to configure",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "param_$",
                "n_regs": ["N_PARAMETERS"],
                "description": "Shape dependent parameter # $",
                "direction": "RW",
                "fields":[]
            }
        ]
    }
 **/
