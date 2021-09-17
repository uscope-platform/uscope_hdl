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

module enable_generator #(parameter BASE_ADDRESS = 0, COUNTER_WIDTH = 32, EXTERNAL_TIMEBASE_ENABLE = 0)(
    input wire        clock,
    input wire        ext_timebase,
    input wire        reset,
    input wire        gen_enable_in,
    output wire        enable_out,
    Simplebus.slave sb
);

    reg [COUNTER_WIDTH-1:0] period;
    wire [COUNTER_WIDTH-1:0] count;
    reg [31:0] latched_adress;
    reg [31:0] latched_writedata;
    reg state,act_state_ended, bus_enable;
    reg [COUNTER_WIDTH-1:0] enable_threshold_1;


    generate
        if(EXTERNAL_TIMEBASE_ENABLE==1)begin
            assign enable_out = synchronized_tb;
        end else begin
            assign enable_out = comparator_out;
        end
    endgenerate
    wire comparator_out;
    reg synchronized_tb,prev_comp_out;

    always_ff@(posedge clock) begin
        if(period == 0 || period == 1) begin
            synchronized_tb <= ext_timebase;
        end else begin
            prev_comp_out <= comparator_out;
            if(comparator_out & ~prev_comp_out)begin
                synchronized_tb<= 1;
            end else begin
                synchronized_tb<= 0;
            end
            
        end
       
    end
    
    defparam counter.COUNTER_WIDTH = COUNTER_WIDTH;
    defparam counter.EXTERNAL_TIMEBASE_ENABLE = EXTERNAL_TIMEBASE_ENABLE;
    enable_generator_counter counter(
        .clock(clock),
        .reset(reset),
        .external_timebase(ext_timebase),
        .gen_enable_in(bus_enable | gen_enable_in),
        .period(period),
        .counter_out(count)
    );

    defparam comparator_1.COUNTER_WIDTH = COUNTER_WIDTH;
    defparam comparator_1.CLOCK_MODE = "FALSE";
    enable_comparator comparator_1(
        .clock(clock),
        .reset(reset),
        .enable_treshold(enable_threshold_1),
        .count(count),
        .enable_out(comparator_out)
    );


    // FSM states
    localparam idle_state = 0, act_state = 1;

    //latch bus writes
    always @(posedge clock) begin : sb_registration_logic
        if(~reset) begin
            latched_adress<=0;
            latched_writedata<=0;
        end else begin
            if(sb.sb_write_strobe & state == idle_state) begin
                latched_adress <= sb.sb_address-BASE_ADDRESS;
                latched_writedata <= sb.sb_write_data;
            end 
        end
    end

    always @ (posedge clock) begin : control_state_machine
        if (~reset) begin
            state <=idle_state;
            act_state_ended <= 0;
            bus_enable<=0;
            sb.sb_ready <= 1;
        end else begin
            // Determine the next state
            case (state)
                idle_state: //wait for command
                    if(sb.sb_write_strobe) begin
                        sb.sb_ready <=0;
                        state <= act_state;
                    end else
                        state <=idle_state;
                act_state: // Act on shadowed write
                    if(act_state_ended) begin
                        state <= idle_state;
                        sb.sb_ready <=1;
                    end else begin
                        state <= act_state;
                    end
            endcase
            // act
            case (state)
                idle_state: begin
                        act_state_ended <= 0;
                    end
                act_state: begin
                    case (latched_adress)
                        32'h00: begin
                            bus_enable <= latched_writedata[0];
                        end
                        32'h04: begin
                            period <= latched_writedata[31:0];
                        end
                        32'h08: begin
                            enable_threshold_1 <= latched_writedata[31:0];
                        end
                    endcase
                    act_state_ended<=1;
                    end
            endcase
        end
    end

endmodule