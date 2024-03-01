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


    reg [31:0] cu_write_registers [6:0];
    reg [31:0] cu_read_registers [6:0];
    
    axil_simple_register_cu #(
        .N_READ_REGISTERS(7),
        .N_WRITE_REGISTERS(7),
        .REGISTERS_WIDTH(32),
        .ADDRESS_MASK('h1f)
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(cu_read_registers),
        .output_registers(cu_write_registers),
        .axil(axi_in)
    );

    wire restart_acquiisition;
    wire [1:0] trigger_mode;
    wire [31:0] trigger_level;
    reg [7:0] channel_selector;
    
    assign trigger_mode = cu_write_registers[0];
    assign trigger_level = cu_write_registers[1];
    assign dma_base_addr[31:0] = cu_write_registers[2];
    assign dma_base_addr[63:32] = cu_write_registers[3];
    assign channel_selector = cu_write_registers[4];
    assign trigger_point = cu_write_registers[5];
    assign restart_acquiisition = cu_write_registers[6];

    assign cu_read_registers = cu_write_registers;

    wire[31:0] unrolled_data [N_CHANNELS-1:0];
    wire unrolled_valid [N_CHANNELS-1:0];

    generate
        genvar i;
        for(i = 0; i<N_CHANNELS; i++)begin
            assign unrolled_data[i] = data_in[i].data;
            assign unrolled_valid[i] = data_in[i].valid;
        end
    endgenerate


    wire [31:0] selected_data;
    wire selected_valid;
    assign selected_data = unrolled_data[channel_selector];
    assign selected_valid = unrolled_valid[channel_selector];

    initial trigger_out <= 0;

    reg [31:0] selected_data_dly;
    wire rising_edge, falling_edge;

    assign rising_edge = selected_data >= trigger_level && selected_data_dly < trigger_level;
    assign falling_edge = selected_data <= trigger_level && selected_data_dly > trigger_level;



    enum reg [2:0] {
        wait_fill = 0,
        run = 1,
        stop = 2
    } state = wait_fill;

    reg [15:0] fill_ctr = 0;


    always @(posedge clock) begin
        selected_data_dly <= selected_data;
        case (state)
            wait_fill : begin
                if(fill_ctr == MEMORY_DEPTH)begin
                    state <= run;
                end
                fill_ctr <= fill_ctr + 1;
            end
            run : begin
                if(selected_valid)begin
                   
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
            end
            stop : begin
                if(restart_acquiisition)
                    state <= run;
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
                "description": "Channel used to trigger the scope",
                "direction": "RW"  
            },
            {
                "name": "buffer_addr_high",
                "offset": "0xC",
                "description": "Point in the buffer where the trigger will be",
                "direction": "RW"  
            },
            {
                "name": "channel_selector",
                "offset": "0x10",
                "description": "Writing an address to this register triggers the related signal",
                "direction": "RW"  
            },
            {
                "name": "trigger_point",
                "offset": "0x14",
                "description": "Acknowledge the last captured trigger",
                "direction": "RW"  
            }
            ]
    }  
    **/
