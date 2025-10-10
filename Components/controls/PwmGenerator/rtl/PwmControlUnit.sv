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


module PwmControlUnit #( 
    INITIAL_STOPPED_STATE = 0,
    N_PWM = 3*2*2
)(
    input wire        clock,
    input wire        reset,
    input wire        counter_status,
    output reg [2:0]  timebase_setting,
    output reg        timebase_enable,
    output reg        timebase_external_enable,
    output reg        counter_run,
    output reg        sync,
    output wire [15:0] sync_out_select,
    output wire [15:0] sync_out_delay,
    output reg [N_PWM-1:0] counter_stopped_state,
    axi_lite.slave axi_in
);

    reg [31:0] cu_write_registers [2:0];
    reg [31:0] cu_read_registers [2:0];
    
    wire [31:0] control_register;

    assign control_register = cu_write_registers[0];
    assign sync_out_select = cu_write_registers[1];
    assign sync_out_delay = cu_write_registers[2];


    axil_simple_register_cu #(
        .N_READ_REGISTERS(3),
        .N_WRITE_REGISTERS(3),
        .REGISTERS_WIDTH(32),
        .ADDRESS_MASK('hf)
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(cu_read_registers),
        .output_registers(cu_write_registers),
        .axil(axi_in)
    );

    assign cu_read_registers = cu_write_registers;

    reg wait_sync_reset;

    always_ff @(posedge clock ) begin
        if (~reset) begin
            timebase_setting <=0;
            sync <= 0;
            timebase_enable <=0;
            timebase_external_enable <=0;
            counter_stopped_state <= INITIAL_STOPPED_STATE;
            counter_run <= 0;
            wait_sync_reset <= 0;
        end else begin
            if(!wait_sync_reset)begin
                if(control_register[6]) begin
                    sync <= 1; 
                    wait_sync_reset <= 1;
                end else begin
                    if(~|counter_status)begin
                        timebase_setting <= control_register[2:0];
                        timebase_enable <= control_register[3];
                        timebase_external_enable <= control_register[4];    
                    end
                    counter_run <= control_register[5];
                    counter_stopped_state[N_PWM-1:0] <= control_register[22:7];    
                end
            end else begin
                sync <= 0;
                if(!control_register[6]) begin
                    wait_sync_reset <= 0;
                end
                if(~|counter_status)begin
                    timebase_setting <= control_register[2:0];
                    timebase_enable <= control_register[3];
                    timebase_external_enable <= control_register[4];    
                end
                counter_run <= control_register[5];
                counter_stopped_state[N_PWM-1:0] <= control_register[22:7];    
            end
            
        end
    end 

endmodule



    /**
       {
        "name": "PwmControlUnit",
        "type": "parametric_peripheral",
        "registers":[
            {
                "name": "ctrl",
                "n_regs": ["1"],
                "description": "Pwm modulator global Control register",
                "direction": "RW",
                "fields": [
                    {
                        "name":"tb_div",
                        "description": "Timebase frequency divisor",
                        "n_fields":["1"],
                        "start_position": 0,
                        "length": 3
                    },
                    {
                        "name":"tb_en",
                        "description": "Timebase enable",
                        "n_fields":["1"],
                        "start_position": 3,
                        "length": 1
                    },
                    {
                        "name":"tb_ext_en",
                        "description": "Enable External timebase",
                        "n_fields":["1"],
                        "start_position": 4,
                        "length": 1
                    },
                    {
                        "name":"counter_run",
                        "description": "Start all counters in the PWM generator module",
                        "n_fields":["1"],
                        "start_position": 5,
                        "length": 1
                    },
                    {
                        "name":"sync",
                        "description": "Instantly reload all counters (use to syncronize multiple independent PWM generators)",
                        "n_fields":["1"],
                        "start_position": 6,
                        "length": 1
                    },
                    {
                        "name":"stop_state",
                        "description": "Default state of the pwm outputs when the counter is not running",
                        "n_fields":["1"],
                        "start_position": 7,
                        "length": 12
                    }
                ]
            }
        ]
       }  
    **/
