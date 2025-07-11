
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


module multichannel_constant #(
    parameter CONSTANT_WIDTH = 32,
    parameter N_CHANNELS = 11,
    parameter N_CONSTANTS = 3
)(
    input wire        clock,
    input wire        reset,
    input wire        sync,
    axi_stream.master const_out,
    axi_lite.slave axil
);


    reg [CONSTANT_WIDTH-1:0] constant_data_memory [0:N_CONSTANTS-1][0:N_CHANNELS-1];
    reg [CONSTANT_WIDTH-1:0] constant_dest_memory [0:N_CONSTANTS-1][0:N_CHANNELS-1];

    reg [31:0] cu_write_registers [5:0];
    reg [31:0] cu_read_registers [5:0];


    axil_simple_register_cu #(
        .N_READ_REGISTERS(6),
        .N_WRITE_REGISTERS(6),
        .REGISTERS_WIDTH(32),
        .ADDRESS_MASK('hff),
        .N_TRIGGER_REGISTERS(2),
        .TRIGGER_REGISTERS_IDX({0,4})
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(cu_read_registers),
        .output_registers(cu_write_registers),
        .trigger_out({latch_constant, clear_constant}),
        .axil(axil)
    );

    reg wait_sync;

    reg [31:0] constant_low_bytes;
    reg [31:0] constant_high_bytes;
    reg [31:0] constant_dest;
    reg [15:0] channel_selector;
    reg [15:0] constant_selector;
    reg [7:0] active_channels;


    assign constant_low_bytes = cu_write_registers[0];
    assign constant_high_bytes = cu_write_registers[1];
    assign constant_dest = cu_write_registers[2];
    assign {channel_selector, constant_selector} = cu_write_registers[3];
    assign active_channels = cu_write_registers[5];

    assign cu_read_registers = cu_write_registers;

    reg [0:N_CONSTANTS-1] active_constants;

    always_ff @(posedge clock) begin
        if (~reset) begin
            for(int i = 0; i < N_CONSTANTS; i++) begin
                for(int j = 0; j < N_CHANNELS; j++) begin
                    constant_data_memory[i][j] <= 0;
                    constant_dest_memory[i][j] <= 0;
                end
            end
        end else begin
            if(latch_constant)begin
                constant_data_memory[constant_selector][channel_selector] <= {constant_high_bytes, constant_low_bytes};
                constant_dest_memory[constant_selector][channel_selector] <= constant_dest;
                active_constants[constant_selector] <= 1;
            end
            if(clear_constant)begin
                constant_data_memory[constant_selector][channel_selector] <= 0;
                constant_dest_memory[constant_selector][channel_selector] <= 0;
                active_constants[constant_selector] <= 0;
            end
        end
    end


    

    reg[7:0] const_counter = 0;
    reg[7:0] channel_counter = 0;

    wire early_advance = channel_counter == active_channels-1 && active_channels != 0;
    wire regular_advance = channel_counter == N_CHANNELS-1;
    enum logic [2:0]{
       idle_state = 0,
       output_state = 1,
       advance_state = 2
    } constant_sender_state = idle_state;

    always_ff @(posedge clock) begin
        if (~reset) begin
            constant_sender_state <= idle_state;
            const_out.data <= 0;
            const_out.dest <= 0;
            const_out.valid <= 0;
        end else begin
            const_out.valid <= 0;
            case (constant_sender_state)
                idle_state: begin
                    if (sync) begin
                        constant_sender_state <= output_state;
                    end
                end

                output_state: begin

                    if( regular_advance | early_advance)begin
                        channel_counter <= 0;
                        constant_sender_state <= advance_state;
                    end else begin
                        channel_counter <= channel_counter + 1;
                    end
                    if(const_out.ready) begin
                        const_out.data <= constant_data_memory[const_counter][channel_counter];
                        const_out.dest <= constant_dest_memory[const_counter][channel_counter];
                        const_out.valid <= 1;
                    end
                end

                advance_state: begin
                    if(const_counter == N_CONSTANTS-1) begin
                        const_counter <= 0;
                        constant_sender_state <= idle_state;
                    end else begin
                        if(active_constants[const_counter]) begin
                            constant_sender_state <= output_state;
                        end
                        const_counter <= const_counter + 1;
                    end
                end
            endcase
        end
    end



endmodule


    /**
       {
        "name": "axis_constant",
        "type": "peripheral",
        "registers":[
            {
                "name": "low",
                "offset": "0x0",
                "description": "Least significant bytes of the constant",
                "direction": "RW"
            },
            {
                "name": "high",
                "offset": "0x4",
                "description": "Most significant bytes of the constant",
                "direction": "RW"
            },
            {
                "name": "dest",
                "offset": "0x8",
                "description": "Value of the AXI stream dest signal associated with the constant",
                "direction": "RW"
            },
            {
                "name": "selectors",
                "offset": "0xC",
                "description": "Channel selector for constants manipulation",
                "direction": "RW",
                fields": [
                    {
                        "name": "channel_selector",
                        "description": "Channel selector for the constant",
                        "start_position": 0,
                        "length": 16
                    },
                    {
                        "name": "constant_selector",
                        "description": "Constant selector for the constant",
                        "direction": "RW", 
                        "start_position": 16,
                        "length": 16
                    }
                ]
            },
            {
                "name": "clear_address",
                "offset": "0x10",
                "description": "write here to clear the selected constant",
                "direction": "RW"
            },
            {
                "name": "active_channels",
                "offset": "0x14",
                "description": "Number of active channels, with 0 all channels are active",
                "direction": "RW"
            }
        ]
    }  
    **/
