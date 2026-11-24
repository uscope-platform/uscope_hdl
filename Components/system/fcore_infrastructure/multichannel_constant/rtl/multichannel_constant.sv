
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


module multichannel_constant #(
    parameter CONSTANT_WIDTH = 32,
    parameter N_CHANNELS = 11,
    parameter N_CONSTANTS = 3
)(
    input wire        clock,
    input wire        reset,
    input wire        sync,
    output reg [7:0] n_active_constants,
    axi_stream.master const_out,
    axi_lite.slave axil
);

    initial n_active_constants = 0;

    wire latch_constant, clear_constant;

    reg [CONSTANT_WIDTH-1:0] constant_data_memory [0:N_CONSTANTS-1][0:N_CHANNELS-1];
    reg [CONSTANT_WIDTH-1:0] constant_dest_memory [0:N_CONSTANTS-1][0:N_CHANNELS-1];
    reg [CONSTANT_WIDTH-1:0] constant_user_memory [0:N_CONSTANTS-1][0:N_CHANNELS-1];

    typedef struct packed {
        reg [15:0] channel_index;
        reg [15:0] constant_index;
    } selector_register;

    typedef struct {
        reg [31:0] constant_low_bytes;
        reg [31:0] constant_high_bytes;
        reg [31:0] constant_dest;
        selector_register selector;
        reg [31:0] clear_address;
        reg [23:0] rsvd_1; reg [7:0] active_channels;
        reg [31:0] constant_user;
    } multichannel_constant_registers;
    
    multichannel_constant_registers registers;

    wire latch_parameters;

    axil_simple_register_cu #(
        .READ_TYPE(multichannel_constant_registers),
        .WRITE_TYPE(multichannel_constant_registers),
        .ADDRESS_MASK('hff),
        .TRIGGER_MASK('{constant_low_bytes: 1, clear_address:1, default: 0})
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(registers),
        .output_registers(registers),
        .trigger_out('{clear_constant, latch_constant}),
        .axil(axil)
    );

    reg [N_CONSTANTS-1:0] active_constants = 0;

    always_ff @(posedge clock) begin
        if (~reset) begin
            for(int i = 0; i < N_CONSTANTS; i++) begin
                for(int j = 0; j < N_CHANNELS; j++) begin
                    constant_data_memory[i][j] <= 0;
                    constant_dest_memory[i][j] <= 0;
                    constant_user_memory[i][j] <= 0;
                end
            end
        end else begin
            if(latch_constant)begin
                constant_data_memory[registers.selector.constant_index][registers.selector.channel_index] <= {registers.constant_high_bytes, registers.constant_low_bytes};
                constant_dest_memory[registers.selector.constant_index][registers.selector.channel_index] <= registers.constant_dest;
                constant_user_memory[registers.selector.constant_index][registers.selector.channel_index] <= registers.constant_user;
                if(!active_constants[registers.selector.constant_index]) n_active_constants <= n_active_constants + 1;
                active_constants[registers.selector.constant_index] <= 1;
            end
            if(clear_constant)begin
                constant_data_memory[registers.selector.constant_index][registers.selector.channel_index] <= 0;
                constant_dest_memory[registers.selector.constant_index][registers.selector.channel_index] <= 0;
                constant_user_memory[registers.selector.constant_index][registers.selector.channel_index] <= 0;
                active_constants[registers.selector.constant_index] <= 0;
                n_active_constants <= n_active_constants - 1;
            end
        end
    end




    reg[7:0] const_counter = 0;
    reg[7:0] const_pointer = 0;
    reg[7:0] channel_counter = 0;

    wire early_advance = channel_counter == registers.active_channels-1 && registers.active_channels != 0;
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
            const_out.tlast <= 0;
            case (constant_sender_state)
                idle_state: begin
                    const_pointer <= 0;
                    const_counter <= 0;
                    channel_counter <= 0;
                    if (sync && n_active_constants != 0) begin
                        constant_sender_state <= output_state;
                    end
                end

                output_state: begin

                    if(const_out.ready) begin
                        if( regular_advance | early_advance)begin
                            if(const_counter == n_active_constants-1) const_out.tlast <= 1;
                            const_pointer <= const_pointer + 1;
                            channel_counter <= 0;
                            constant_sender_state <= advance_state;
                        end else begin
                            channel_counter <= channel_counter + 1;
                        end
                        const_out.data <= constant_data_memory[const_pointer][channel_counter];
                        const_out.dest <= constant_dest_memory[const_pointer][channel_counter];
                        const_out.user <= constant_user_memory[const_pointer][channel_counter];
                        const_out.valid <= 1;
                    end
                end

                advance_state: begin
                    if(const_counter == n_active_constants-1) begin
                        const_counter <= 0;
                        constant_sender_state <= idle_state;
                    end else begin
                        if(active_constants[const_pointer]) begin
                            constant_sender_state <= output_state;
                            const_counter <= const_counter + 1;
                        end else begin
                            const_pointer <= const_pointer + 1;
                        end
                    end
                end
            endcase
        end
    end



endmodule


    /**
       {
        "name": "multichannel_constant",
        "type": "parametric_peripheral",
        "registers":[
            {
                "name": "low",
                "n_regs": ["1"],
                "description": "Least significant bytes of the constant",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "high",
                "n_regs": ["1"],
                "description": "Most significant bytes of the constant",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "dest",
                "n_regs": ["1"],
                "description": "Value of the AXI stream dest signal associated with the constant",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "selectors",
                "n_regs": ["1"],
                "description": "Channel selector for constants manipulation",
                "direction": "RW",
                "fields": [
                    {
                        "name": "constant_index",
                        "description": "Constant selector for the constant",
                        "direction": "RW",
                        "n_fields":["1"],
                        "start_position": 0,
                        "length": 16
                    },
                    {
                        "name": "channel_index",
                        "description": "Channel selector for the constant",
                        "start_position": 16,
                        "n_fields":["1"],
                        "length": 16
                    }
                ]
            },
            {
                "name": "clear_address",
                "n_regs": ["1"],
                "description": "write here to clear the selected constant",
                "direction": "RW"
            },
            {
                "name": "active_channels",
                "n_regs": ["1"],
                "description": "Number of active channels, with 0 all channels are active",
                "direction": "RW"
            },
            {
                "name": "constant_user",
                "n_regs": ["1"],
                "description": "Value of the AXI stream user signal associated with the constant",
                "direction": "RW"
            }
        ]
    }
    **/
