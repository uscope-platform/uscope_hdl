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

module enable_generator_3 #(parameter BASE_ADDRESS = 0, COUNTER_WIDTH = 32)(
    input wire        clock,
    input wire        reset,
    input wire        gen_enable_in,
    output wire enable_out_1,
    output wire enable_out_2,
    output wire enable_out_3,
    Simplebus.slave sb
);

    reg [COUNTER_WIDTH-1:0] period;
    wire [COUNTER_WIDTH-1:0] count;
    reg [31:0] latched_adress;
    reg [31:0] latched_writedata;
    reg state,act_state_ended, bus_enable;
    
    reg [COUNTER_WIDTH-1:0] enable_threshold_1;
    reg [COUNTER_WIDTH-1:0] enable_threshold_2;
    reg [COUNTER_WIDTH-1:0] enable_threshold_3;

    wire [31:0] int_read_data;
    
    assign sb.sb_read_data = sb.sb_read_valid ? int_read_data : 0;

    //REGISTER FILE FOR READBACK
    RegisterFile Registers(
        .clk(clock),
        .reset(reset),
        .addr_a(sb.sb_address-BASE_ADDRESS),
        .data_a(sb.sb_write_data),
        .we_a(sb.sb_write_strobe),
        .q_a(int_read_data)
    );

    enable_generator_counter counter(
        .clock(clock),
        .reset(reset),
        .gen_enable_in(bus_enable | gen_enable_in),
        .period(period),
        .counter_out(count)
    );
    
    defparam comparator_1.COUNTER_WIDTH = COUNTER_WIDTH;
    enable_comparator comparator_1(
        .clock(clock),
        .reset(reset),
        .enable_treshold(enable_threshold_1),
        .count(count),
        .enable_out(enable_out_1)
    );
    
    defparam comparator_2.COUNTER_WIDTH = COUNTER_WIDTH;
    enable_comparator comparator_2(
        .clock(clock),
        .reset(reset),
        .enable_treshold(enable_threshold_2),
        .count(count),
        .enable_out(enable_out_2)
    );
    
    defparam comparator_3.COUNTER_WIDTH = COUNTER_WIDTH;
    enable_comparator comparator_3(
        .clock(clock),
        .reset(reset),
        .enable_treshold(enable_threshold_3),
        .count(count),
        .enable_out(enable_out_3)
    );
    

    // FSM states
    parameter idle_state = 0, act_state = 1;

    //latch bus writes
    always @(posedge clock) begin : sb_registration_logic
        if(~reset) begin
            latched_adress<=0;
            latched_writedata<=0;
        end else begin
            if(sb.sb_write_strobe & state == idle_state) begin
                latched_adress <= sb.sb_address;
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
            
            enable_threshold_1 <= 0;
            enable_threshold_2 <= 0;
            enable_threshold_3 <= 0;
        end else begin
            sb.sb_read_valid <= 0;
            // Determine the next state
            case (state)
                idle_state: //wait for command
                    if(sb.sb_read_strobe) begin
                        sb.sb_read_valid <= 1;
                    end else if(sb.sb_write_strobe) begin
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
                        BASE_ADDRESS+32'h00: begin
                            bus_enable <= latched_writedata[0];
                        end
                        BASE_ADDRESS+32'h04: begin
                            period <= latched_writedata[31:0];
                        end
                        BASE_ADDRESS+32'h8: begin
                            enable_threshold_1 <= latched_writedata[31:0];
                        end
                        BASE_ADDRESS+32'hc: begin
                            enable_threshold_2 <= latched_writedata[31:0];
                        end
                        BASE_ADDRESS+32'h10: begin
                            enable_threshold_3 <= latched_writedata[31:0];
                        end
                        
                    endcase
                    act_state_ended<=1;
                    end
            endcase
        end
    end

endmodule