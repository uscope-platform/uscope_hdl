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

`timescale 10ns / 1ns
`include "interfaces.svh"

module ChainControlUnit #(
    parameter BASE_ADDRESS = 0,
    N_CHANNELS = 4,
    COUNTER_WIDTH=16
)(
    input wire clock,
    input wire reset,
    input wire counter_running,
    output reg [COUNTER_WIDTH-1:0] timebase_shift,
    output reg [2:0] counter_mode,
    output reg [COUNTER_WIDTH-1:0] counter_start_data,
    output reg [COUNTER_WIDTH-1:0] counter_stop_data,
    output reg [COUNTER_WIDTH-1:0] comparator_tresholds [N_CHANNELS*2-1:0],
    output reg [1:0] output_enable [N_CHANNELS-1:0],
    output reg [COUNTER_WIDTH-1:0] deadtime [N_CHANNELS-1:0],
    output reg deadtime_enable [N_CHANNELS-1:0],
    axi_lite.slave axi_in
);

    reg [31:0] cu_write_registers [N_CHANNELS*3+5:0];
    reg [31:0] cu_read_registers [N_CHANNELS*3+5:0];
    
    localparam [31:0] THRESH_LOW_IV [N_CHANNELS-1:0] = '{N_CHANNELS{32'b0}};
    localparam [31:0] THRESH_HIGH_IV [N_CHANNELS-1:0] = '{N_CHANNELS{32'hffffffff}};
    localparam [31:0] DT_IV [N_CHANNELS-1:0] = '{N_CHANNELS{32'h50}};
    localparam [31:0] OTHER_IV [5:0] = '{6{32'b0}};
    localparam [31:0] INITIAL_REGISTER_VALUES [N_CHANNELS*3+5:0] = {OTHER_IV, DT_IV, THRESH_HIGH_IV, THRESH_LOW_IV};

    axil_simple_register_cu #(
        .N_READ_REGISTERS((N_CHANNELS*3+5)+1),
        .N_WRITE_REGISTERS((N_CHANNELS*3+5)+1),
        .REGISTERS_WIDTH(32),
        .ADDRESS_MASK('hff),
        .INITIAL_OUTPUT_VALUES(INITIAL_REGISTER_VALUES)
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(cu_read_registers),
        .output_registers(cu_write_registers),
        .axil(axi_in)
    );

    always_latch begin
        for(integer i=0; i<N_CHANNELS*2; i=i+1) begin 
            comparator_tresholds[i] <= cu_write_registers[i];
            timebase_shift <= cu_write_registers[N_CHANNELS*3+2];
        end 
    end 

    always_ff @(posedge clock) begin
        if(!reset)begin
            for(integer i=0; i<N_CHANNELS; i=i+1) begin 
                deadtime[i] <= 0;
            end
            counter_mode <= 0;
            counter_start_data <= 0;
            counter_stop_data <= 0;
        end else begin
            if(~counter_running) begin

                for(integer i=0; i<N_CHANNELS; i=i+1) begin 
                   deadtime[i] <= cu_write_registers[N_CHANNELS*2+i];
                end

                counter_start_data <= cu_write_registers[N_CHANNELS*3];
                counter_stop_data <= cu_write_registers[N_CHANNELS*3+1];
               
                
                for(integer i=0; i<N_CHANNELS*2; i=i+2) begin 
                   output_enable[i/2] <= {cu_write_registers[N_CHANNELS*3+3][i+1],cu_write_registers[N_CHANNELS*3+3][i]};
                end

                for(integer i=0; i<N_CHANNELS; i=i+1) begin 
                   deadtime_enable[i] <= cu_write_registers[N_CHANNELS*3+4][i];
                end
                counter_mode <= cu_write_registers[N_CHANNELS*3+5][2:0];

            end
        end    
    end

    assign cu_read_registers = cu_write_registers;


endmodule

    /**
       {
        "name": "ChainControlUnit",
        "type": "parametric_peripheral",
        "registers":[
            {
                "name": "tresh_$L",
                "n_regs": ["N_CHANNELS"],
                "description": "Comparator $ treshold low",
                "fields":[],
                "direction": "RW"
            },
            {
                "name": "tresh_$H",
                "n_regs": ["N_CHANNELS"],
                "description": "Comparator $ treshold high",
                "fields":[],
                "direction": "RW"
            },
            {
                "name": "deadtime_$",
                "n_regs": ["N_CHANNELS"],
                "description": "Length of deadtime automatically inserted in pair A (if enabled)",
                "fields":[],
                "direction": "RW"
            },
            {
                "name": "counter_start",
                "n_regs": ["1"],
                "description": "Start Value for the PWM generator",
                "fields":[],
                "direction": "RW"
            },
            {
                "name": "counter_stop",
                "n_regs": ["1"],
                "description": "Stop Value for the PWM generator",
                "fields":[],
                "direction": "RW"
            },
            {
                "name": "tb_shift",
                "n_regs": ["1"],
                "description": "Carrier phase shift",
                "fields":[],
                "direction": "RW"
            },
            {
                "name": "out_en",
                "n_regs": ["1"],
                "description": "Output enable register",
                "fields":[],
                "direction": "RW",
                "fields":[
                    {
                        "name":"out_$",
                        "description": "enable output pair $",
                        "start_position": 0,
                        "length": 2,
                        "n_fields": ["N_CHANNELS"]
                    }
                ]
            },
            {
                "name": "dt_en",
                "n_regs": ["1"],
                "description": "Deadtime insertion enable register",
                "direction": "RW",
                "fields":[
                    {
                        "name":"pair_$",
                        "description": "Enable deadtime insertion pair $",
                        "start_position": 0,
                        "length": 1,
                        "n_fields": ["N_CHANNELS"]
                    }
                ]
            },
            {
                "name": "ctrl",
                "n_regs": ["1"],
                "description": "Chain control register",
                "direction": "RW",
                "fields":[
                    {
                        "name":"mode",
                        "description": "Chain counter mode",
                        "start_position": 0,
                        "length": 3
                    }
                ]
            }
        ]
       }
    **/
