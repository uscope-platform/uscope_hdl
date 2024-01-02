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

module programmable_sequencer #(
    MAX_STEPS = 5,
    COUNTER_WIDTH = 16
)(
    input wire clock,
    input wire reset,
    input wire enable,
    input wire [MAX_STEPS-1:0] step_done,
    output reg [MAX_STEPS-1:0] step_start,
    axi_lite.slave axi_in
);

    parameter N_REGISTERS = 50;

    reg [31:0] cu_write_registers [N_REGISTERS-1:0];
    reg [31:0] cu_read_registers [N_REGISTERS-1:0];
    

    axil_simple_register_cu #(
        .N_READ_REGISTERS(N_REGISTERS),
        .N_WRITE_REGISTERS(N_REGISTERS),
        .REGISTERS_WIDTH(32),
        .ADDRESS_MASK('hfff),
        .INITIAL_OUTPUT_VALUES('{N_REGISTERS{32'b0}})
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(cu_read_registers),
        .output_registers(cu_write_registers),
        .axil(axi_in)
    );

    wire [15:0] timebase_divider;
    wire burst_mode;
    wire [7:0] n_steps;
    wire [15:0] sequence_ordering[MAX_STEPS-1:0];

    wire [15:0] stepping_delay;

    assign n_steps = cu_write_registers[0][7:0];
    assign burst_mode = cu_write_registers[0][8];
    assign timebase_divider = cu_write_registers[1];
    assign stepping_delay = cu_write_registers[2];

    genvar n;

    generate
        for(n=0; n<MAX_STEPS; n = n+1)begin
            assign sequence_ordering[n] = cu_write_registers[3+n];
        end
    endgenerate

    wire sequencer_timebase;
    assign sequencer_timebase = clock;

    enum reg [2:0] {
        s_idle = 0,
        s_start_step = 1,
        s_wait_done = 2,
        s_inter_step_delay = 3
    } sequencer_state = s_idle;


    reg [7:0] current_step;
    reg [15:0] stepping_counter = 0;

    always_ff @(posedge clock) begin
        case (sequencer_state)
            s_idle:begin
                current_step <= 0;
                step_start <= 0;
                stepping_counter <= 0;
                if(enable) begin
                    sequencer_state <= s_start_step;
                end
            end
            s_start_step: begin
                step_start[sequence_ordering[current_step]] <= 1;
                sequencer_state <= s_wait_done;
                stepping_counter <= 0;
            end
            s_wait_done: begin
                step_start <= 0;
                if(step_done[sequence_ordering[current_step]])begin
                    sequencer_state <= s_inter_step_delay;
                end
            end
            s_inter_step_delay:begin
                if(sequencer_timebase)begin
                    if(stepping_counter == stepping_delay) begin
                        if(current_step == n_steps-1)begin
                            current_step <= 0;
                            if(burst_mode) begin
                                sequencer_state <= s_idle;
                            end else begin
                            sequencer_state <= s_start_step;
                            end
                        end else begin
                            current_step <= current_step + 1;
                            sequencer_state <= s_start_step;
                        end
                    end else begin
                        stepping_counter <= stepping_counter + 1;
                    end
                end
            end
        endcase
    end

endmodule