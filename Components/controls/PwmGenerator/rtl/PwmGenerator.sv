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
    axi_lite.slave axi_in,
    axi_stream.slave modulation_in
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

    axi_stream internal_bus();

    wire [31:0] read_chain_data [N_CHAINS-1:0];
    wire [31:0] read_global_data;

    axi_stream read_req();
    axi_stream read_resp();
    axi_stream write_req();

    axil_external_registers_cu #(
        .REGISTERS_WIDTH(32),
        .REGISTERED_BUFFERS(0),
        .TRANSPARENT_MODE("TRUE"),
        .READ_DELAY(1)
    ) CU (
        .clock(clock),
        .reset(reset),
        .read_address(read_req),
        .read_data(read_resp),
        .write_data(write_req),
        .axi_in(axi_in)
    ); 
    reg [3:0] read_address;

    reg wait_read_result;
    always_ff @(posedge clock)begin
        write_req.ready <= 1;
        read_req.ready <= 1; 
        read_resp.valid <= 0;
        internal_bus.valid <= 0;
        modulation_in.ready <= 1;

        if(modulation_in.valid) begin
            internal_bus.data <= modulation_in.data;
            internal_bus.dest <= modulation_in.dest>>2;
            internal_bus.user <= modulation_in.user;
            internal_bus.valid <= 1;
            internal_bus.tlast <= 0;
        end else if(write_req.valid)begin
            internal_bus.data <= write_req.data;
            internal_bus.dest <= write_req.dest[7:0]>>2;
            internal_bus.user <= write_req.dest[11:8];
            internal_bus.valid <= 1;
            internal_bus.tlast <= 0;
        end 

        if(read_req.valid)begin
            internal_bus.dest <= read_req.data[7:0]>>2;
            internal_bus.user <= read_req.data[11:8];
            read_address <= read_req.data[11:8];
            internal_bus.valid <= 1;
            internal_bus.tlast <= 1;
            wait_read_result <= 1;
        end
        if(wait_read_result)begin
            wait_read_result <= 0;
            if(read_address == 0)
                read_resp.data <= read_global_data;
            else 
                read_resp.data <= read_chain_data[read_address];
            read_resp.valid <= 1;
        end
    end

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
        .read_response(read_global_data),
        .modulation_in(internal_bus)
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
            internal_pwm_out[j*N_CHANNELS+:N_CHANNELS] = partial_pwm_out_a[j];
            internal_pwm_out[N_CHAINS*N_CHANNELS+j*N_CHANNELS+:N_CHANNELS] = partial_pwm_out_b[j];
        end
    end


    generate
        for( i = 0; i<N_CHAINS; i++)begin
            pwmChain #(
                .COUNTER_WIDTH(COUNTER_WIDTH),
                .N_CHANNELS(N_CHANNELS),
                .HR_ENABLE(HR_ENABLE),
                .ENANCING_MODE(ENANCING_MODE),
                .CHAIN_ADDRESS(i+1)
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
                .read_response(read_chain_data[i]),
                .modulation_in(internal_bus)
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
