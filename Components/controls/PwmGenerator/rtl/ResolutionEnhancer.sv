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

module ResolutionEnhancer #(
    parameter ENABLE = "TRUE",
    ENANCING_MODE = "DUTY"
)(
    input wire clock,
    input wire [2:0] high_resolution_clock,
    input wire reset,
    input wire in,
    input wire [2:0] count,
    output wire out
);


 

    generate 
        if(ENABLE == "FALSE")begin
            assign out = in;
        end else begin
            if(ENANCING_MODE == "DUTY") begin

                reg in_del;

                wire hr_pulse_gating_r;
                assign hr_pulse_gating_r = ~in_del & in;
                reg hr_pulse_gating_f;

                always_ff@(posedge clock)begin
                    in_del <= in;
                    hr_pulse_gating_f <=  in_del & ~in;
                end

                wire hr_pulse_gating = (hr_pulse_gating_f | hr_pulse_gating_r );

                wire [7:0] high_res_pulses;

                assign high_res_pulses[0] = hr_pulse_gating & ~high_resolution_clock[0] & ~high_resolution_clock[1] & ~high_resolution_clock[2] & clock;
                assign high_res_pulses[1] = hr_pulse_gating &  high_resolution_clock[0] & ~high_resolution_clock[1] & ~high_resolution_clock[2] & clock;
                assign high_res_pulses[2] = hr_pulse_gating &  high_resolution_clock[0] &  high_resolution_clock[1] &  ~high_resolution_clock[2] & clock;
                assign high_res_pulses[3] = hr_pulse_gating &  high_resolution_clock[0] &  high_resolution_clock[1] &  high_resolution_clock[2] & clock;

                assign high_res_pulses[4] = hr_pulse_gating &  high_resolution_clock[0] &  high_resolution_clock[1] &  high_resolution_clock[2] & ~clock;
                assign high_res_pulses[5] = hr_pulse_gating & ~high_resolution_clock[0] &  high_resolution_clock[1] &  high_resolution_clock[2] & ~clock;
                assign high_res_pulses[6] = hr_pulse_gating & ~high_resolution_clock[0] & ~high_resolution_clock[1] &  high_resolution_clock[2] & ~clock;
                assign high_res_pulses[7] = hr_pulse_gating & ~high_resolution_clock[0] & ~high_resolution_clock[1] & ~high_resolution_clock[2] & ~clock;

                wire [7:0] high_res_extensions;

                assign high_res_extensions[0] = high_res_pulses[7];
                assign high_res_extensions[1] = |high_res_pulses[7:6];
                assign high_res_extensions[2] = |high_res_pulses[7:5];
                assign high_res_extensions[3] = |high_res_pulses[7:4];
                assign high_res_extensions[4] = |high_res_pulses[7:3];
                assign high_res_extensions[5] = |high_res_pulses[7:2];
                assign high_res_extensions[6] = |high_res_pulses[7:1];
                assign high_res_extensions[7] = |high_res_pulses[7:0];

                wire selected_extension_r, selected_extension_f;

                assign selected_extension_r = hr_pulse_gating_r & high_res_extensions[count-1] & count != 0 ;
                assign selected_extension_f = hr_pulse_gating_f & ~high_res_extensions[7-count] & count != 0 ;


                wire selected_delay_r, selected_delay_f;

                assign selected_delay_r = hr_pulse_gating_r &  high_res_extensions[7-count];
                assign selected_delay_f = hr_pulse_gating_f &  ~high_res_extensions[7-count];

                assign out = in_del | selected_extension_r | selected_extension_f; 

            end else if(ENANCING_MODE=="DELAY") begin

            reg delayed_out;

            assign out = delayed_out;

            reg [7:0] delayed_in;

            always_ff@(posedge high_resolution_clock[0])begin
                delayed_in[1] <= in;
            end

            always_ff@(posedge high_resolution_clock[1])begin
                delayed_in[2] <= in;
            end

            always_ff@(posedge high_resolution_clock[2])begin
                delayed_in[3] <= in;
            end

            always_ff@(negedge clock)begin
                delayed_in[4] <= in;
            end

            always_ff@(negedge high_resolution_clock[0])begin
                delayed_in[5] <= in;
            end

            always_ff@(negedge high_resolution_clock[1])begin
                delayed_in[6] <= in;
            end

            always_ff@(negedge high_resolution_clock[2])begin
                delayed_in[7] <= in;
            end

            always_comb begin
                if(count == 0)begin
                    delayed_out <= in;
                end else begin
                    delayed_out <= delayed_in[count];
                end
            end
        end
    end
    endgenerate

endmodule