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
    Simplebus.slave sb
);

    parameter CHAIN_1_ADDRESS = BASE_ADDRESS + 8'h4;
    parameter CHAIN_2_ADDRESS = CHAIN_1_ADDRESS + 8'h3c;
    parameter BOUNDARY = CHAIN_2_ADDRESS + 8'h40;

    // internal interfaces

    Simplebus sb_slave_1();
    Simplebus sb_slave_2();
    Simplebus sb_slave_3();

    //Common signals
    wire internal_timebase,timebase_enable,sync;
    wire [2:0] dividerSetting;
    wire counter_run, stop_request;
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

    SimplebusInterconnect_M1_S3 #(
        .SLAVE_1_LOW(BASE_ADDRESS),
        .SLAVE_1_HIGH(CHAIN_1_ADDRESS),
        .SLAVE_2_LOW(CHAIN_1_ADDRESS),
        .SLAVE_2_HIGH(CHAIN_2_ADDRESS),
        .SLAVE_3_LOW(CHAIN_2_ADDRESS),
        .SLAVE_3_HIGH(BOUNDARY)
    ) xbar(
        .clock(clock),
        .master(sb),
        .slave_1(sb_slave_1),
        .slave_2(sb_slave_2),
        .slave_3(sb_slave_3)
    );
    
    
    PwmControlUnit #(
        .BASE_ADDRESS(BASE_ADDRESS),
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
        .stop_request(stop_request),
        .counter_stopped_state(counter_stopped_state),
        .sb(sb_slave_1)
    );

    TimebaseGenerator timebase_generator(
        .clockIn(clock),
        .reset(reset),
        .enable(timebase_enable),
        .timebaseOut(internal_timebase),
        .dividerSetting(dividerSetting)
    );

    pwmChain #(
        .BASE_ADDRESS(CHAIN_1_ADDRESS),
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
        .sb(sb_slave_2)
    );

    
    pwmChain #(
        .BASE_ADDRESS(CHAIN_2_ADDRESS),
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
        .sb(sb_slave_3)
    );


    
endmodule