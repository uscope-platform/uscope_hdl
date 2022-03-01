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

module PwmGenerator #(parameter BASE_ADDRESS = 32'h43c00000, COUNTER_WIDTH=16, INITIAL_STOPPED_STATE = 0)(
    input wire clock,
    input wire reset,
    input wire ext_timebase,
    input wire fault,
    output wire timebase,
    output reg [11:0] pwm_out,
    axi_lite.slave axi_in
);

    //Common signals
    wire internal_timebase,timebase_enable,sync;
    wire [2:0] dividerSetting;
    wire counter_run;
    reg selected_timebase;
    wire ext_timebase_enable;
    wire [1:0] counter_status;
    wire [11:0] counter_stopped_state;
    wire [11:0] internal_pwm_out;

    reg [1:0] stop_chain = 0;
    assign timebase = internal_timebase;
    
    always@(posedge clock)begin
        if(counter_status[0] & internal_pwm_out[5:0] == counter_stopped_state[5:0])begin
            stop_chain[0]<=1;
        end else 
            stop_chain[0] <= 0;

        if(counter_status[0] & ~fault)begin
            pwm_out[5:0] = internal_pwm_out[5:0];
        end else begin
            pwm_out[5:0] = counter_stopped_state[5:0];
        end
        
        if(counter_status[1] & internal_pwm_out[11:6] == counter_stopped_state[11:6])begin
            stop_chain[1]<=1;
        end else 
            stop_chain[1] <= 0;

        if(counter_status[1] & ~fault)begin
            pwm_out[11:6] = internal_pwm_out[11:6];
        end else begin
            pwm_out[11:6] = counter_stopped_state[11:6];
        end
        
    end


    always@(posedge clock)begin
        if(~reset)begin
            selected_timebase<=internal_timebase;
        end else begin
            if(ext_timebase_enable)
                selected_timebase <= ext_timebase;
            else
            selected_timebase <= internal_timebase;
        
        end
    end



    localparam GEN_CONTROLLER_ADDRESS_AXI = BASE_ADDRESS;
    localparam CHAIN_1_ADDRESS_AXI = BASE_ADDRESS+'h100;
    localparam CHAIN_2_ADDRESS_AXI = BASE_ADDRESS+'h200;

    axi_lite #(.INTERFACE_NAME("CONTROLLER")) controller_axi();
    axi_lite #(.INTERFACE_NAME("CHAIN 1")) chain_1_axi();
    axi_lite #(.INTERFACE_NAME("CHAIN 2")) chain_2_axi();

    axil_crossbar_interface #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(32),
        .NM(1),
        .NS(3),
        .SLAVE_ADDR('{GEN_CONTROLLER_ADDRESS_AXI, CHAIN_1_ADDRESS_AXI, CHAIN_2_ADDRESS_AXI}),
        .SLAVE_MASK('{3{32'hf00}})
    ) axi_xbar (
        .clock(clock),
        .reset(reset),
        .slaves('{axi_in}),
        .masters('{controller_axi, chain_1_axi, chain_2_axi})
    );

    
    
    PwmControlUnit #(
        .INITIAL_STOPPED_STATE(INITIAL_STOPPED_STATE)
    ) pwm_cu(
        .clock(clock),
        .reset(reset),
        .counter_status(counter_status),
        .timebase_setting(dividerSetting),
        .timebase_enable(timebase_enable),
        .timebase_external_enable(ext_timebase_enable),
        .counter_run(counter_run),
        .sync(sync),
        .counter_stopped_state(counter_stopped_state),
        .axi_in(controller_axi)
    );

    TimebaseGenerator timebase_generator(
        .clockIn(clock),
        .reset(reset),
        .enable(timebase_enable),
        .timebaseOut(internal_timebase),
        .dividerSetting(dividerSetting)
    );

    pwmChain #(
        .COUNTER_WIDTH(COUNTER_WIDTH)
    ) chain_1(
        .clock(clock),
        .reset(reset),
        .sync(sync),
        .stop_request(stop_chain[0]),
        .timebase(selected_timebase),
        .external_counter_run(counter_run),
        .counter_status(counter_status[0]),
        .out_a(internal_pwm_out[2:0]),
        .out_b(internal_pwm_out[5:3]),
        .axi_in(chain_1_axi)
    );

    
    pwmChain #(
        .COUNTER_WIDTH(COUNTER_WIDTH)
    ) chain_2(
        .clock(clock),
        .reset(reset),
        .sync(sync),
        .stop_request(stop_chain[1]),
        .timebase(selected_timebase),
        .external_counter_run(counter_run),
        .counter_status(counter_status[1]),
        .out_a(internal_pwm_out[8:6]),
        .out_b(internal_pwm_out[11:9]),
        .axi_in(chain_2_axi)
    );


    
endmodule


    /**
       {
        "name": "PwmGenerator",
        "type": "peripheral",
        "registers":[
            {
                "name": "gl_ctrl",
                "offset": "0x0",
                "description": "Global Control register",
                "direction": "RW",
                "fields": [
                    {
                        "name":"tb_div",
                        "description": "Timebase frequency divisor",
                        "start_position": 0,
                        "length": 3
                    },
                    {
                        "name":"tb_en",
                        "description": "Timebase enable",
                        "start_position": 3,
                        "length": 1
                    },
                    {
                        "name":"tb_ext_en",
                        "description": "Enable External timebase",
                        "start_position": 4,
                        "length": 1
                    },
                    {
                        "name":"counter_run",
                        "description": "Start all counters in the PWM generator module",
                        "start_position": 5,
                        "length": 1
                    },
                    {
                        "name":"sync",
                        "description": "Instantly reload all counters (use to syncronize multiple independent PWM generators)",
                        "start_position": 6,
                        "length": 1
                    },
                    {
                        "name":"stop_state",
                        "description": "Default state of the pwm outputs when the counter is not running",
                        "start_position": 7,
                        "length": 12
                    }
                ]
            },
            {
                "name": "ch0_tresh_AL",
                "offset": "0x4",
                "description": "Comparator 0 treshold low",
                "direction": "RW"
            },
            {
                "name": "ch0_tresh_Bl",
                "offset": "0x8",
                "description": "Comparator B treshold low",
                "direction": "RW"
            },
            {
                "name": "ch0_tresh_CL",
                "offset": "0xC",
                "description": "Comparator C treshold low",
                "direction": "RW"
            },
            {
                "name": "ch0_tresh_AH",
                "offset": "0x10",
                "description": "Comparator A treshold high",
                "direction": "RW"
            },
            {
                "name": "ch0_tresh_BH",
                "offset": "0x14",
                "description": "Comparator B treshold high",
                "direction": "RW"
            },
            {
                "name": "ch0_tresh_CH",
                "offset": "0x18",
                "description": "Comparator C treshold high",
                "direction": "RW"
            },
            {
                "name": "ch0_deadtime_A",
                "offset": "0x1c",
                "description": "Length of deadtime automatically inserted in pair A (if enabled)",
                "direction": "RW"
            },
            {
                "name": "ch_0_deadtime_B",
                "offset": "0x20",
                "description": "Length of deadtime automatically inserted in pair B (if enabled)",
                "direction": "RW"
            },
            {
                "name": "ch0_deadtime_C",
                "offset": "0x24",
                "description": "Length of deadtime automatically inserted in pair C (if enabled)",
                "direction": "RW"
            },
            {
                "name": "ch0_counter_start",
                "offset": "0x28",
                "description": "Start Value for the PWM generator",
                "direction": "RW"
            },
            {
                "name": "ch0_counter_stop",
                "offset": "0x2c",
                "description": "Stop Value for the PWM generator counter",
                "direction": "RW"
            },
            {
                "name": "ch0_tb_shift",
                "offset": "0x30",
                "description": "Delay to be applied to the counter enable signal (to apply shift between the counters)",
                "direction": "RW"
            },
            {
                "name": "ch0_out_en",
                "offset": "0x34",
                "description": "Output enable register",
                "direction": "RW",
                "fields":[
                    {
                        "name":"out_a",
                        "description": "enable output pair A of chain 0",
                        "start_position": 0,
                        "length": 2
                    },
                    {
                        "name":"out_b",
                        "description": "enable output pair B of chain 0",
                        "start_position": 2,
                        "length": 2
                    },
                    {
                        "name":"out_c",
                        "description": "enable output pair C of chain 0",
                        "start_position": 4,
                        "length": 2
                    }
                ]
            },
            {
                "name": "ch0_dt_en",
                "offset": "0x38",
                "description": "Deadtime insertion enable register",
                "direction": "RW",
                "fields":[
                    {
                        "name":"pair_a",
                        "description": "Enable deadtime insertion pair A of chain 0",
                        "start_position": 0,
                        "length": 1
                    },
                    {
                        "name":"pair_b",
                        "description": "Enable deadtime insertion pair B of chain 0",
                        "start_position": 1,
                        "length": 1
                    },
                    {
                        "name":"pair_c",
                        "description": "Enable deadtime insertion pair C of chain 0",
                        "start_position": 2,
                        "length": 1
                    }
                ]
            },
            {
                "name": "ch0_ctrl",
                "offset": "0x3C",
                "description": "Chain 0 control register",
                "direction": "RW",
                "fields":[
                    {
                        "name":"mode",
                        "description": "Chain 0 counter mode",
                        "start_position": 0,
                        "length": 3
                    }
                ]
            },
            {
                "name": "ch1_tresh_AL",
                "offset": "0x40",
                "description": "Comparator 0 treshold low",
                "direction": "RW"
            },
            {
                "name": "ch1_tresh_Bl",
                "offset": "0x44",
                "description": "Comparator B treshold low",
                "direction": "RW"
            },
            {
                "name": "ch1_tresh_CL",
                "offset": "0x48",
                "description": "Comparator C treshold low",
                "direction": "RW"
            },
            {
                "name": "ch1_tresh_AH",
                "offset": "0x4C",
                "description": "Comparator A treshold high",
                "direction": "RW"
            },
            {
                "name": "ch1_tresh_BH",
                "offset": "0x50",
                "description": "Comparator B treshold high",
                "direction": "RW"
            },
            {
                "name": "ch1_tresh_CH",
                "offset": "0x54",
                "description": "Comparator C treshold high",
                "direction": "RW"
            },
            {
                "name": "ch1_deadtime_A",
                "offset": "0x58",
                "description": "Length of deadtime automatically inserted in pair A (if enabled)",
                "direction": "RW"
            },
            {
                "name": "ch_1_deadtime_B",
                "offset": "0x5C",
                "description": "Length of deadtime automatically inserted in pair B (if enabled)",
                "direction": "RW"
            },
            {
                "name": "ch1_deadtime_C",
                "offset": "0x60",
                "description": "Length of deadtime automatically inserted in pair C (if enabled)",
                "direction": "RW"
            },
            {
                "name": "ch1_counter_start",
                "offset": "0x64",
                "description": "Start Value for the PWM generator",
                "direction": "RW"
            },
            {
                "name": "ch1_counter_stop",
                "offset": "0x68",
                "description": "Stop Value for the PWM generator counter",
                "direction": "RW"
            },
            {
                "name": "ch1_tb_shift",
                "offset": "0x6C",
                "description": "Delay to be applied to the counter enable signal (to apply shift between the counters)",
                "direction": "RW"
            },
            {
                "name": "ch1_out_en",
                "offset": "0x70",
                "description": "Output enable register",
                "direction": "RW",
                "fields":[
                    {
                        "name":"out_a",
                        "description": "enable output pair A of chain 1",
                        "start_position": 0,
                        "length": 2
                    },
                    {
                        "name":"out_b",
                        "description": "enable output pair B of chain 1",
                        "start_position": 2,
                        "length": 2
                    },
                    {
                        "name":"out_c",
                        "description": "enable output pair C of chain 1",
                        "start_position": 4,
                        "length": 2
                    }
                ]
            },
            {
                "name": "ch1_dt_en",
                "offset": "0x74",
                "description": "Deadtime insertion enable register",
                "direction": "RW",
                "fields":[
                    {
                        "name":"pair_a",
                        "description": "Enable deadtime insertion pair A of chain 1",
                        "start_position": 0,
                        "length": 1
                    },
                    {
                        "name":"pair_b",
                        "description": "Enable deadtime insertion pair B of chain 1",
                        "start_position": 1,
                        "length": 1
                    },
                    {
                        "name":"pair_c",
                        "description": "Enable deadtime insertion pair C of chain 1",
                        "start_position": 2,
                        "length": 1
                    }
                ]
            },
            {
                "name": "ch1_ctrl",
                "offset": "0x78",
                "description": "Chain 1 control register",
                "direction": "RW",
                "fields":[
                    {
                        "name":"mode",
                        "description": "Chain 1 counter mode",
                        "start_position": 0,
                        "length": 3
                    }
                ]
            }
        ]
       }  
    **/
