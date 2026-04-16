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

module ChainControlUnit #(
    N_CHANNELS = 4,
    COUNTER_WIDTH=16,
    CHAIN_ADDRESS=0
)(
    input wire clock,
    input wire reset,
    input wire counter_running,
    output reg [COUNTER_WIDTH-1:0] timebase_shift,
    output reg [2:0] counter_mode,
    output reg [COUNTER_WIDTH-1:0] counter_start_data,
    output reg [COUNTER_WIDTH-1:0] counter_stop_data,
    output reg [COUNTER_WIDTH-1:0] tresholds_low [N_CHANNELS-1:0],
    output reg [COUNTER_WIDTH-1:0] tresholds_high [N_CHANNELS-1:0],
    output reg [1:0] output_enable [N_CHANNELS-1:0],
    output reg [COUNTER_WIDTH-1:0] deadtime [N_CHANNELS-1:0],
    output reg [31:0] read_response,
    output reg deadtime_enable [N_CHANNELS-1:0],
    axi_stream.slave modulation_in
);

    localparam [31:0] THRESH_LOW_IV [N_CHANNELS-1:0] = '{N_CHANNELS{32'b0}};
    localparam [31:0] THRESH_HIGH_IV [N_CHANNELS-1:0] = '{N_CHANNELS{32'hffffffff}};
    localparam [31:0] DT_IV [N_CHANNELS-1:0] = '{N_CHANNELS{32'h50}};
    localparam [31:0] OTHER_IV [5:0] = '{6{32'b0}};
    localparam [31:0] INITIAL_REGISTER_VALUES [N_CHANNELS*3+5:0]  = {OTHER_IV, DT_IV, THRESH_HIGH_IV, THRESH_LOW_IV};


    reg [31:0] cu_registers [N_CHANNELS*3+5:0] = INITIAL_REGISTER_VALUES;


    always_ff @(posedge clock) begin
        read_response <= 0;
        if(modulation_in.valid && modulation_in.user == CHAIN_ADDRESS) begin
            if(~modulation_in.tlast)begin
                cu_registers[modulation_in.dest] <= modulation_in.data;
            end else begin
                read_response <= cu_registers[modulation_in.dest];
            end
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
            for(integer i=0; i<N_CHANNELS; i=i+1) begin 
                tresholds_low[i] <= cu_registers[i];
                tresholds_high[i] <= cu_registers[i+N_CHANNELS];
            end 
            
            timebase_shift <= cu_registers[N_CHANNELS*3+2];
            if(~counter_running) begin
                
                for(integer i=0; i<N_CHANNELS; i=i+1) begin 
                   deadtime[i] <= cu_registers[N_CHANNELS*2+i];
                end

                counter_start_data <= cu_registers[N_CHANNELS*3];
                counter_stop_data <= cu_registers[N_CHANNELS*3+1];
               
                
                for(integer i=0; i<N_CHANNELS*2; i=i+2) begin 
                   output_enable[i/2] <= {cu_registers[N_CHANNELS*3+3][i+1],cu_registers[N_CHANNELS*3+3][i]};
                end

                for(integer i=0; i<N_CHANNELS; i=i+1) begin 
                   deadtime_enable[i] <= cu_registers[N_CHANNELS*3+4][i];
                end
                counter_mode <= cu_registers[N_CHANNELS*3+5][2:0];

            end
        end    
    end


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
