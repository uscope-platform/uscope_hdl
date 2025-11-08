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

module PwmGenerator #(
    parameter BASE_ADDRESS = 32'h43c00000,
    N_CHANNELS = 4,
    HR_ENABLE = "FALSE",
    ENANCING_MODE = "DUTY",
    COUNTER_WIDTH=16, 
    INITIAL_STOPPED_STATE = 0,
    N_CHAINS = 2,
    N_PWM = N_CHAINS*N_CHANNELS*2,
    PRAGMA_MKFG_MODULE_TOP = "PwmGenerator"
)(
    input wire clock,
    input wire reset,
    input wire [2:0] high_resolution_clock,
    input wire ext_timebase,
    input wire fault,
    output wire timebase,
    output reg [N_PWM-1:0] pwm_out,
    output reg sync_out,
    axi_lite.slave axi_in
);

    //Common signals
    wire [N_CHAINS-1:0] chains_sync_out;
    wire internal_timebase,timebase_enable,sync;
    wire [2:0] dividerSetting;
    wire counter_run;
    wire selected_timebase;
    wire ext_timebase_enable;
    wire [N_CHAINS-1:0] counter_status;
    wire [N_PWM-1:0] counter_stopped_state;
    reg [N_PWM-1:0] internal_pwm_out;

    reg [N_CHAINS-1:0] stop_chain = 0;
    assign timebase = internal_timebase;


    wire [15:0] sync_out_select;
    wire [15:0] sync_out_delay;

    genvar i;

    for(i=0; i<N_CHAINS;i++)begin
        assign pwm_out[(i+1)*2*N_CHANNELS-1:i*2*N_CHANNELS] = counter_status[i] & ~fault ?
            internal_pwm_out[(i+1)*2*N_CHANNELS-1:i*2*N_CHANNELS] : 
            counter_stopped_state[(i+1)*2*N_CHANNELS-1:i*2*N_CHANNELS];
    end


    assign selected_timebase = internal_timebase;

    typedef logic [31:0] addr_init_t [N_CHAINS+1];
    function addr_init_t ADDR_CALC();
        ADDR_CALC[N_CHAINS] = BASE_ADDRESS;
        for(int i = 1; i<=N_CHAINS; i++)begin
            ADDR_CALC[N_CHAINS-i] = BASE_ADDRESS+'h100*i;
        end
    endfunction

    localparam [31:0] AXI_ADDRESSES [N_CHAINS:0] = ADDR_CALC();


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


    SyncEngine #(
        .N_CHAINS(N_CHAINS)
    ) SyncEngine (
        .clock(clock),
        .enable(counter_run),
        .sync_in(chains_sync_out),
        .sync_select(sync_out_select),
        .sync_delay(sync_out_delay),
        .sync_out(sync_out)
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
        .sync_out_select(sync_out_select),
        .sync_out_delay(sync_out_delay),
        .counter_stopped_state(counter_stopped_state),
        .axi_in(internal_bus[N_CHAINS])
    );

    wire fast_count;
    assign fast_count = dividerSetting == 3'b0;


    TimebaseGenerator timebase_generator(
        .clock(clock),
        .reset(reset),
        .fast_count(fast_count),
        .enable(timebase_enable),
        .counter_status(counter_run),
        .timebaseOut(internal_timebase),
        .dividerSetting(dividerSetting)
    );

    wire [N_CHANNELS-1:0] partial_pwm_out_a [N_CHAINS-1:0];
    wire [N_CHANNELS-1:0] partial_pwm_out_b [N_CHAINS-1:0];

    always_comb begin
        for (int j=0; j < N_CHAINS; j++)begin
            internal_pwm_out[j*N_CHANNELS+:N_CHANNELS] = partial_pwm_out_a[(N_CHAINS-1)-j];
            internal_pwm_out[N_CHAINS*N_CHANNELS+j*N_CHANNELS+:N_CHANNELS] = partial_pwm_out_b[(N_CHAINS-1)-j];
        end
    end


    generate
        for( i = 0; i<N_CHAINS; i++)begin
            pwmChain #(
                .COUNTER_WIDTH(COUNTER_WIDTH),
                .N_CHANNELS(N_CHANNELS),
                .HR_ENABLE(HR_ENABLE),
                .ENANCING_MODE(ENANCING_MODE)
            ) chain(
                .clock(clock),
                .high_resolution_clock(high_resolution_clock),
                .reset(reset),
                .sync(sync),
                .fast_count(fast_count),
                .stop_request(stop_chain[i]),
                .timebase(selected_timebase),
                .external_counter_run(counter_run),
                .counter_status(counter_status[i]),
                .sync_out(chains_sync_out[i]),
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
