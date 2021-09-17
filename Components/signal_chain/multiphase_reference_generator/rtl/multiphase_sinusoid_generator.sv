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

module multiphase_sinusoid_generator #(parameter N_PHASES=6, BASE_ADDRESS='h43c00000)(
    input wire clock,
    input wire reset,
    input wire [15:0] phase_shifts [N_PHASES-1:0],
    axi_stream.slave phase,
    axi_stream.master sin_out,
    axi_stream.master cos_out
);

    reg [15:0] latched_phase;
    reg[$clog2(N_PHASES)-1:0] phase_in_counter;
    reg[$clog2(N_PHASES)-1:0] phase_out_counter;
    reg [5:0] lut_enable;
    reg start_output_fsm;
    
    axi_stream theta [N_PHASES]();
    axi_stream sin [N_PHASES]();
    axi_stream cos [N_PHASES]();

    defparam theta[0].DATA_WIDTH = 16;
    defparam theta[1].DATA_WIDTH = 16;
    defparam theta[2].DATA_WIDTH = 16;
    defparam theta[3].DATA_WIDTH = 16;
    defparam theta[4].DATA_WIDTH = 16;
    defparam theta[5].DATA_WIDTH = 16;
    
    generate
        genvar i;
        for (i = 0; i<N_PHASES; i= i+1) begin
            assign theta[i].data = (latched_phase+phase_shifts[i]);
            assign theta[i].valid = lut_enable[i];
            assign theta[i].dest = i;
            SinCosLUT cos_LUTn(
                .clock(clock),
                .reset(reset),
                .theta(theta[i]),
                .cos(cos[i]),
                .sin(sin[i])
            );     
        end
    endgenerate

    always_ff@(posedge clock)begin
        if(~reset) begin
            cos_out.data <= 0;
            cos_out.dest <= 0;
            cos_out.valid <= 0;
            sin_out.data <= 0;
            sin_out.dest <= 0;
            sin_out.valid <= 0;
        end else begin
            cos_out.data <= cos[0].data | cos[1].data | cos[2].data | cos[3].data | cos[4].data | cos[5].data;
            cos_out.dest <= cos[0].dest | cos[1].dest | cos[2].dest | cos[3].dest | cos[4].dest | cos[5].dest;
            cos_out.valid <= cos[0].valid | cos[1].valid | cos[2].valid | cos[3].valid | cos[4].valid | cos[5].valid;

            sin_out.data <= sin[0].data | sin[1].data | sin[2].data | sin[3].data | sin[4].data | sin[5].data;
            sin_out.dest <= sin[0].dest | sin[1].dest | sin[2].dest | sin[3].dest | sin[4].dest | sin[5].dest;
            sin_out.valid <= sin[0].valid | sin[1].valid | sin[2].valid | sin[3].valid | sin[4].valid | sin[5].valid;
        end
    end

    enum reg {
        input_idle_state = 0,
        input_working_state = 1
    } input_state;

    always_ff @(posedge clock)begin : lut_input_fsm
        if(~reset)begin
            phase.ready <= 1;
            latched_phase <= 0;
            start_output_fsm<=0;
            input_state <= input_idle_state;
            phase_in_counter <= 0;
        end else begin
            lut_enable <= 0;
            case (input_state)
                input_idle_state: begin
                   if(phase.valid)begin
                       input_state <= input_working_state;
                       latched_phase <= phase.data;
                   end 
                end
                input_working_state: begin
                    lut_enable[phase_in_counter] <= 1;
                    if(phase_in_counter==1)start_output_fsm<=0;
                    else start_output_fsm <= 0;
                    if(phase_in_counter == N_PHASES-1)begin
                        phase_in_counter <= 0;
                        input_state <= input_idle_state;
                    end else begin
                        phase_in_counter <= phase_in_counter+1;
                    end
                end
            endcase
        end
    end


endmodule