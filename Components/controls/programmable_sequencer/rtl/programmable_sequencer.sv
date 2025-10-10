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
    SKIPPING_COUNTER_WIDTH=5,
    COUNTER_WIDTH = 16
)(
    input wire clock,
    input wire reset,
    input wire enable,
    input wire [MAX_STEPS-1:0] step_done,
    output reg [MAX_STEPS-1:0] step_start,
    output reg [MAX_STEPS-1:0] skipped_starts,
    axi_lite.slave axi_in
);

    parameter N_REGISTERS = 2*MAX_STEPS+3;

    reg [31:0] cu_write_registers [N_REGISTERS-1:0];
    reg [31:0] cu_read_registers [N_REGISTERS-1:0];
    

    localparam [31:0] INIT_VAL [N_REGISTERS-1:0] = '{default:0};
    
    axil_simple_register_cu #(
        .N_READ_REGISTERS(N_REGISTERS),
        .N_WRITE_REGISTERS(N_REGISTERS),
        .REGISTERS_WIDTH(32),
        .ADDRESS_MASK('hfff),
        .INITIAL_OUTPUT_VALUES(INIT_VAL)
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(cu_read_registers),
        .output_registers(cu_write_registers),
        .axil(axi_in)
    );

    assign cu_read_registers = cu_write_registers;

    wire [15:0] timebase_divider;
    wire burst_mode;
    wire [7:0] n_steps;
    wire [15:0] sequence_ordering[MAX_STEPS-1:0];
    wire [15:0] stepping_delay;
    wire [SKIPPING_COUNTER_WIDTH-1:0] pulse_skipping_setting [MAX_STEPS-1:0];
    
    assign n_steps = cu_write_registers[0][7:0];
    assign burst_mode = cu_write_registers[0][8];
    assign timebase_divider = cu_write_registers[1];
    assign stepping_delay = cu_write_registers[2];

    genvar n;

    generate
        for(n=0; n<MAX_STEPS; n = n+1)begin
            assign sequence_ordering[n] = cu_write_registers[3+n*2];
            assign pulse_skipping_setting[n] = cu_write_registers[3+n*2+1];
        end
    endgenerate

    reg [SKIPPING_COUNTER_WIDTH-1:0] pulse_skipping_counters [MAX_STEPS-1:0] = '{default:0};


    enum reg [2:0] {
        s_idle = 0,
        s_start_step = 1,
        s_wait_done = 2,
        s_inter_step_delay = 3
    } sequencer_state = s_idle;


    reg [7:0] current_step;
    reg [15:0] stepping_counter = 0;

    wire [SKIPPING_COUNTER_WIDTH-1:0] skipping_target;
    assign skipping_target = pulse_skipping_setting[current_step] != 0 ? (pulse_skipping_setting[current_step] - 1) : 0;

    always_ff @(posedge clock) begin
        case (sequencer_state)
            s_idle:begin
                current_step <= 0;
                step_start <= 0;
                stepping_counter <= 0;
                pulse_skipping_counters = '{MAX_STEPS{0}};

                if(enable) begin
                    sequencer_state <= s_start_step;
                end
            end
            s_start_step: begin
                stepping_counter <= 0;
                if(pulse_skipping_counters[current_step] == skipping_target)begin
                    step_start[sequence_ordering[current_step]] <= 1;
                    pulse_skipping_counters[current_step] <= 0;
                end else begin
                    skipped_starts[sequence_ordering[current_step]] <= 1;
                    pulse_skipping_counters[current_step] <= pulse_skipping_counters[current_step]+1;
                end
                sequencer_state <= s_wait_done;
            end
            s_wait_done: begin
                step_start <= 0;
                skipped_starts <= 0;
                if(step_done[sequence_ordering[current_step]])begin
                    sequencer_state <= s_inter_step_delay;
                end
            end
            s_inter_step_delay:begin
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
        endcase
    end

endmodule


 /**
    {
        "name": "programmable_sequencer",
        "alias": "programmable_sequencer",
        "type": "parametric_peripheral",
        "registers":[
            {
                "name": "control",
                "n_regs": ["1"],
                "description": "Sequencer control register",
                "direction": "RW",
                "fields":[
                     {
                        "name":"n_steps",
                        "description": "number of steps in the sequence",
                        "n_fields":["1"],
                        "start_position": 0,
                        "length": 8
                    },
                    {
                        "name":"burst_mode",
                        "description": "Enable burst mode (one sequence per trigger)",
                        "start_position": 8,
                        "n_fields":["1"],
                        "length": 1
                    }
                ]
            },
            {
                "name": "reserved",
                "n_regs": ["1"],
                "description": "Reserved register, Do not use",
                "fields":[],
                "direction": "RW"
            },
            {
                "name": "step_delay",
                "n_regs": ["1"],
                "description": "Additional delay between sequence steps",
                "fields":[],
                "direction": "RW"
            },
            {
                "name": "step_$",
                "n_regs": ["MAX_STEPS"],
                "description": "This register selects which sequencer output is active for step # $",
                "fields":[],
                "direction": "RW"
            }
        ]
    }
 **/