// Copyright 2021 Filippo Savi
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

module dab_pre_modulation_processor #(
    PWM_BASE_ADDR = 0,
    N_PWM_CHANNELS = 2,
    N_PARAMETERS = 13
)(
    input wire clock,
    input wire reset,
    input wire configure,
    input wire start,
    input wire stop,
    input wire [3:0] update,
    input wire [1:0] modulation_type,
    input wire [15:0] period,
    input wire [15:0] modulation_parameters[N_PARAMETERS-1:0],
    output reg modulator_status,
    output reg done,
    axi_stream.master write_request
);


    axi_stream management_write();
    axi_stream operating_write();

    always_comb begin
        operating_write.ready <= write_request.ready;
        management_write.ready <= write_request.ready;
        if(operating_write.valid)begin
            write_request.data <=  operating_write.data;
            write_request.dest <=  operating_write.dest;
            write_request.user <=  operating_write.user;
            write_request.valid <= operating_write.valid;
            write_request.tlast <= operating_write.tlast;
        end else if(management_write.valid)begin
            write_request.data <=  management_write.data;
            write_request.dest <=  management_write.dest;
            write_request.user <=  management_write.user;
            write_request.valid <= management_write.valid;
            write_request.tlast <= management_write.tlast;
        end else begin
            write_request.data <= 0;
            write_request.dest <= 0;
            write_request.user <= 0;
            write_request.valid <= 0;
            write_request.tlast <= 0;
        end
    end

    ////////////////////////////////////////////
    //           PARAMETER DECODING           //
    ////////////////////////////////////////////

    wire operating_config_done;

    wire [15:0] duty_1;
    assign duty_1 = modulation_parameters[0];
    wire [15:0] duty_2;
    assign duty_2 = modulation_parameters[1];
    wire signed [15:0] phase_shift_1;
    assign phase_shift_1 = modulation_parameters[2];
    wire signed [15:0] phase_shift_2;
    assign phase_shift_2 = modulation_parameters[3];
    wire [15:0] deadtime;
    assign deadtime = modulation_parameters[4];


    PMP_DAB_management_core #(
        .PWM_BASE_ADDR(PWM_BASE_ADDR),
        .N_PWM_CHANNELS(2)
    ) management_core (
        .clock(clock),
        .reset(reset),
        .configure(configure),
        .start(start),
        .stop(stop),
        .done(done),
        .deadtime(deadtime),
        .pwm_config_done(operating_config_done),
        .write_request(management_write)
    );
    

    PMP_DAB_operating_core #(
        .PWM_BASE_ADDR(PWM_BASE_ADDR),
        .N_PWM_CHANNELS(N_PWM_CHANNELS)
    )operating_core(
        .clock(clock),
        .reset(reset),
        .start(start),
        .stop(stop),
        .pwm_config_done(operating_config_done),
        .update(update),
        .modulation_type(modulation_type),
        .period(period),
        .duty_1(duty_1),
        .duty_2(duty_2),
        .phase_shift_1(phase_shift_1),
        .phase_shift_2(phase_shift_2),
        .modulator_status(modulator_status),
        .operating_write(operating_write)
    );

    
endmodule
