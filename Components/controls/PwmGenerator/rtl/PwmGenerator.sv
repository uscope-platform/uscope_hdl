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

module PwmGenerator #(
    parameter BASE_ADDRESS = 32'h43c00000, 
    N_CHANNELS = 4, 
    COUNTER_WIDTH=16, 
    INITIAL_STOPPED_STATE = 0,
    N_CHAINS = 2,
    N_PWM = N_CHAINS*N_CHANNELS*2
)(
    input wire clock,
    input wire reset,
    input wire ext_timebase,
    input wire fault,
    output wire timebase,
    output reg [N_PWM-1:0] pwm_out,
    axi_lite.slave axi_in
);

    //Common signals
    wire internal_timebase,timebase_enable,sync;
    wire [2:0] dividerSetting;
    wire counter_run;
    reg selected_timebase;
    wire ext_timebase_enable;
    wire [1:0] counter_status;
    wire [N_PWM-1:0] counter_stopped_state;
    reg [N_PWM-1:0] internal_pwm_out;

    reg [N_CHAINS-1:0] stop_chain = 0;
    assign timebase = internal_timebase;
    
    always@(posedge clock)begin
        if(counter_status[0] & internal_pwm_out[N_CHANNELS*N_CHAINS-1:0] == counter_stopped_state[N_CHANNELS*N_CHAINS-1:0])begin
            stop_chain[0]<=0;
        end else 
            stop_chain[0] <= 0;

        if(counter_status[0] & ~fault)begin
            pwm_out[N_CHANNELS*N_CHAINS-1:0] = internal_pwm_out[N_CHANNELS*N_CHAINS-1:0];
        end else begin
            pwm_out[N_CHANNELS*N_CHAINS-1:0] = counter_stopped_state[N_CHANNELS*N_CHAINS-1:0];
        end
        
        if(counter_status[1] & internal_pwm_out[N_CHANNELS*N_CHAINS*2-1:N_CHANNELS*N_CHAINS] == counter_stopped_state[N_CHANNELS*N_CHAINS*2-1:N_CHANNELS*N_CHAINS])begin
            stop_chain[0]<=0;
        end else 
            stop_chain[0] <= 0;

        if(counter_status[1] & ~fault)begin
            pwm_out[N_CHANNELS*N_CHAINS*2-1:N_CHANNELS*N_CHAINS] = internal_pwm_out[N_CHANNELS*N_CHAINS*2-1:N_CHANNELS*N_CHAINS];
        end else begin
            pwm_out[N_CHANNELS*N_CHAINS*2-1:N_CHANNELS*N_CHAINS] = counter_stopped_state[N_CHANNELS*N_CHAINS*2-1:N_CHANNELS*N_CHAINS];
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

    typedef logic [31:0] addr_init_t [N_CHAINS+1];
    function addr_init_t ADDR_CALC();
        ADDR_CALC[N_CHAINS] = BASE_ADDRESS;
        for(int i = 1; i<=N_CHAINS; i++)begin
            ADDR_CALC[N_CHAINS-i] = BASE_ADDRESS+'h100*i;
        end
    endfunction 

    localparam [31:0] AXI_ADDRESSES [N_CHAINS:0] = ADDR_CALC(); 


    genvar i;

    axi_lite internal_bus[N_CHAINS+1]();

    axil_crossbar_interface #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(32),
        .NM(1),
        .NS(N_CHAINS+1),
        .SLAVE_ADDR(AXI_ADDRESSES),
        .SLAVE_MASK('{(N_CHAINS+1){32'hf00}})
    ) axi_xbar (
        .clock(clock),
        .reset(reset),
        .slaves('{axi_in}),
        .masters(internal_bus)
    );

    PwmControlUnit #(
        .INITIAL_STOPPED_STATE(INITIAL_STOPPED_STATE),
        .N_PWM(N_PWM)
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
        .axi_in(internal_bus[N_CHAINS])
    );

    TimebaseGenerator timebase_generator(
        .clockIn(clock),
        .reset(reset),
        .enable(timebase_enable),
        .timebaseOut(internal_timebase),
        .dividerSetting(dividerSetting)
    );

    wire [N_CHANNELS-1:0] partial_pwm_out_a [N_CHAINS-1:0];
    wire [N_CHANNELS-1:0] partial_pwm_out_b [N_CHAINS-1:0];

    always_comb begin
        for (int j=0; j < N_CHAINS; j++)begin
            internal_pwm_out[j*N_CHANNELS+:N_CHANNELS] = partial_pwm_out_a[j];
            internal_pwm_out[N_CHAINS*N_CHANNELS+j*N_CHANNELS+:N_CHANNELS] = partial_pwm_out_b[j];
        end
    
    end

    generate
        for( i = 0; i<N_CHAINS; i++)begin
            pwmChain #(
                .COUNTER_WIDTH(COUNTER_WIDTH),
                .N_CHANNELS(N_CHANNELS)
            ) chain(
                .clock(clock),
                .reset(reset),
                .sync(sync),
                .stop_request(stop_chain[i]),
                .timebase(selected_timebase),
                .external_counter_run(counter_run),
                .counter_status(counter_status[i]),
                .out_a(partial_pwm_out_a[i]),
                .out_b(partial_pwm_out_b[i]),
                .axi_in(internal_bus[i])
            );
        end
    endgenerate

endmodule


    /**
        {
            "name": "PwmGenerator",
            "type": "module_hierarchy",
            "children": [
                {
                    "type": "PwmControlUnit",
                    "instance": "pwm_cu",
                    "offset": "0",
                    "children":[]
                },
                {
                    "type": "ChainControlUnit",
                    "instance": "chain_1",
                    "offset": "0x100",
                    "children":[]
                },
                {
                    "type": "ChainControlUnit",
                    "instance": "chain_2",
                    "offset": "0x200",
                    "children":[]
                }
            ]    
        }
    **/
