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

module encoder_interface #(
    parameter COUNTER_WIDTH = 24
)(
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


    typedef struct {
        reg [30:0] reserved; reg enable_index_tracking;
    } encoder_if_control;

    typedef struct {
        reg [31:0] angle_dest;
        reg [31:0] speed_dest;
        reg [31:0] max_count;
        reg [31:0] angle_out;
        reg [31:0] speed_out;
        encoder_if_control control;
    } encoder_interface_read_registers;

    typedef struct {
        reg [31:0] angle_dest;
        reg [31:0] speed_dest;
        reg [31:0] max_count;
        reg [31:0] rsvd_1;
        reg [31:0] rsvd_2;
        encoder_if_control control;
    } encoder_interface_write_registers;

    encoder_interface_read_registers read_registers;
    encoder_interface_write_registers write_registers;

    axil_simple_register_cu #(
        .READ_TYPE(encoder_interface_read_registers),
        .WRITE_TYPE(encoder_interface_write_registers),
        .REGISTERS_WIDTH(32),
        .ADDRESS_MASK('hff)
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(read_registers),
        .output_registers(write_registers),
        .axil(axi_in)
    );

    wire [31:0] angle_out, speed_out;

    assign read_registers.angle_dest = write_registers.angle_dest;
    assign read_registers.speed_dest = write_registers.speed_dest;
    assign read_registers.max_count = write_registers.max_count;
    assign read_registers.angle_out = angle_out;
    assign read_registers.speed_out = speed_out;
    assign read_registers.control = write_registers.control;



    angle_sensing angle_measurement(
        .clock(clock),
        .reset(reset),
        .enable_index_tracking(write_registers.control.enable_index_tracking),
        .output_destination(write_registers.angle_dest),
        .max_count(write_registers.max_count-1),
        .a(a),
        .b(b),
        .z(z),
        .sample(sample_angle),
        .angle(angle),
        .angle_out(angle_out)
    );


    speed_sensing #(
        .COUNTER_WIDTH(COUNTER_WIDTH)
    ) speed_measurement(
        .clock(clock),
        .reset(reset),
        .output_destination(write_registers.speed_dest),
        .z(z),
        .sample(sample_speed),
        .speed(speed),
        .speed_out(speed_out)
    );

endmodule

 /**
    {
        "name": "encoder_interface",
        "type": "parametric_peripheral",
        "registers":[
            {
                "name": "angle_dest",
                "n_regs": ["1"],
                "description": "Destination of the angle measurement axis stream",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "speed_dest",
                "n_regs": ["1"],
                "description": "Destination of the speed measurement axis stream",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "max_count",
                "n_regs": ["1"],
                "description": "Angle counter rollover limit (counter wraps between 0 and max_count-1)",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "angle_out",
                "n_regs": ["1"],
                "description": "Current angle counter value",
                "direction": "R",
                "fields":[]
            },
            {
                "name": "speed_out",
                "n_regs": ["1"],
                "description": "Current speed counter value",
                "direction": "R",
                "fields":[]
            },
            {
                "name": "control",
                "n_regs": ["1"],
                "description": "Encoder interface control register",
                "direction": "RW",
                "fields":[
                    {
                        "name":"enable_index_tracking",
                        "description": "Enables angle counter zeroing on encoder index (z) pulses",
                        "start_position": 0,
                        "n_fields":["1"],
                        "length": 1
                    }
                ]
            }
        ]
    }
 **/
