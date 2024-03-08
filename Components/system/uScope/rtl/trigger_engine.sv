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


module trigger_engine #(
    N_CHANNELS = 6,
    MEMORY_DEPTH = 1023
)(
    input wire        clock,
    input wire        reset,
    axi_stream.slave data_in[N_CHANNELS],
    axi_lite.slave axi_in,
    output reg trigger_out,
    output reg [15:0] trigger_point,
    output reg [63:0] dma_base_addr
);


    reg [31:0] cu_write_registers [7:0];
    reg [31:0] cu_read_registers [7:0];
    
    axil_simple_register_cu #(
        .N_READ_REGISTERS(8),
        .N_WRITE_REGISTERS(8),
        .REGISTERS_WIDTH(32),
        .ADDRESS_MASK('h1f),
        .N_TRIGGER_REGISTERS(1),
        .TRIGGER_REGISTERS_IDX('{7})
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(cu_read_registers),
        .output_registers(cu_write_registers),
        .trigger_out(rearm_trigger),
        .axil(axi_in)
    );

    wire rearm_trigger;
    wire [1:0] acquisition_mode;
    wire [1:0] trigger_mode;
    wire [31:0] trigger_level;
    reg [7:0] channel_selector;
    
    assign trigger_mode = cu_write_registers[0];
    assign trigger_level = cu_write_registers[1];
    assign dma_base_addr[31:0] = cu_write_registers[2];
    assign dma_base_addr[63:32] = cu_write_registers[3];
    assign channel_selector = cu_write_registers[4];
    assign trigger_point = cu_write_registers[5];
    assign acquisition_mode = cu_write_registers[6];

    assign cu_read_registers[6:0] = cu_write_registers[6:0];
    assign cu_read_registers[7] = state;


    wire[31:0] unrolled_data [N_CHANNELS-1:0];
    wire [15:0] unrolled_user [N_CHANNELS-1:0];
    wire unrolled_valid [N_CHANNELS-1:0];

    generate
        genvar i;
        for(i = 0; i<N_CHANNELS; i++)begin
            assign unrolled_data[i] = data_in[i].data;
            assign unrolled_valid[i] = data_in[i].valid;
            assign unrolled_user[i] = data_in[i].user;
        end
    endgenerate


    wire [31:0] selected_data;
    wire [15:0] selected_user;
    wire selected_valid;
    assign selected_data = unrolled_data[channel_selector];
    assign selected_user = unrolled_user[channel_selector];
    assign selected_valid = unrolled_valid[channel_selector];

    initial trigger_out <= 0;

    axi_stream ftoi_in();
    axi_stream ftoi_out();
    axi_stream fixed_out();

    assign ftoi_in.data = selected_data;
    assign ftoi_in.user = selected_user;
    assign ftoi_in.valid = selected_valid;

    float_to_fixed_wrapper ftoi(
        .clock(clock),
        .data_in(ftoi_in),
        .data_out(ftoi_out)
    );


    register_slice #(
        .DATA_WIDTH(32),
        .DEST_WIDTH(32),
        .USER_WIDTH(32),
        .N_STAGES(1),
        .READY_REG(0)
    ) input_matching_delay (
        .clock(clock),
        .reset(reset),
        .in(ftoi_in),
        .out(fixed_out)
    );



    reg [31:0] trigger_comparator_in_dly;
    wire rising_edge, falling_edge;

    assign rising_edge  = $signed(trigger_comparator_in) >= $signed(trigger_level) && $signed(trigger_comparator_in_dly) < $signed(trigger_level);
    assign falling_edge = $signed(trigger_comparator_in) <= $signed(trigger_level) && $signed(trigger_comparator_in_dly) > $signed(trigger_level);

    reg [31:0] trigger_comparator_in;
    always_comb begin
        if(is_axis_float(fixed_out.user))begin
            trigger_comparator_in <= ftoi_out.data;
        end else begin
            trigger_comparator_in <= fixed_out.data;
        end
    end

    enum reg [2:0] {
        wait_fill = 0,
        run = 1,
        stop = 2, 
        free_run = 3
    } state = wait_fill;

    reg [15:0] fill_ctr = 0;


    always @(posedge clock) begin
        trigger_comparator_in_dly <= trigger_comparator_in;
        case (state)
            wait_fill : begin
                if(fill_ctr == MEMORY_DEPTH)begin
                    state <= run;
                end
                fill_ctr <= fill_ctr + 1;
            end
            run : begin
                if(fixed_out.valid)begin
                    case (trigger_mode)
                        0: begin //RISING EDGE TRIGGER
                            trigger_out <= rising_edge;
                        end
                        1:begin //FALLING EDGE TRIGGER
                            trigger_out <= falling_edge;
                        end 
                        2:begin //BOTH EDGE TRIGGER
                            trigger_out <= rising_edge | falling_edge;
                        end
                    endcase
                end
                if(trigger_out && acquisition_mode ==1)begin
                    state <= stop;
                end
                if(acquisition_mode == 2)begin
                    state <= free_run;
                end
            end
            stop : begin
                trigger_out <= 0;
                if(rearm_trigger || acquisition_mode !=1)begin
                    state <= run;
                end
                if(acquisition_mode == 2)begin
                    state <= free_run;
                end
            end
            free_run : begin
                trigger_out <= 1;
                if(acquisition_mode !=2)begin
                    state <= run;
                    trigger_out <= 0;
                end
            end
        endcase
    end


endmodule

    /**
       {
        "name": "trigger_engine",
        "type": "peripheral",
        "registers":[
            {
                "name": "trigger_mode",
                "offset": "0x0",
                "description": "Trigger mode selection",
                "direction": "RW"
            },
            {
                "name": "trigger_level",
                "offset": "0x4",
                "description": "Trigger level",
                "direction": "RW"
            },
            {
                "name": "buffer_addr_low",
                "offset": "0x8",
                "description": "Lower 32 bits of the target dma buffer address",
                "direction": "RW"  
            },
            {
                "name": "buffer_addr_high",
                "offset": "0xC",
                "description": "Higher 32 bits of the target dma buffer address",
                "direction": "RW"  
            },
            {
                "name": "channel_selector",
                "offset": "0x10",
                "description": "Channel used to trigger the scope",
                "direction": "RW"  
            },
            {
                "name": "trigger_point",
                "offset": "0x14",
                "description": "Point in the buffer where the trigger will be positioned",
                "direction": "RW"  
            },
            {
                "name": "acquisition_mode",
                "offset": "0x18",
                "description": "Acquisition mode selector",
                "direction": "RW"  
            },
            {
                "name": "rearm_trigger",
                "offset": "0x1C",
                "description": "Rearm the single acquisition trigger upon write and read acquisition status",
                "direction": "RW"  
            }
            ]
    }  
    **/
