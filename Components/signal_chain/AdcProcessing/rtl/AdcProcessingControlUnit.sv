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

module AdcProcessingControlUnit #(parameter BASE_ADDRESS = 'h43c00000)(
    input wire clock,
    input wire reset,
    input wire data_in_valid,
    Simplebus.slave simple_bus,
    // COMPARATORS
    output reg [1:0]  comparator_address,
    output reg [31:0] comparator_threshold, 
    output reg [1:0] comparator_we,
    output reg [1:0]  latch_mode,
    output reg [1:0]  clear_latch,
    input wire [1:0]  trip_high,
    input wire [1:0]  trip_low,
    // FILTERS
    output reg [3:0]  filter_address,
    output reg [15:0] filter_tap,
    output reg        filter_we,
    output reg        filter_bypass,
    // CALIBRATION
    output reg [2:0]  cal_address,
    output reg [15:0] cal_data,
    output reg        cal_we,
    output reg        gain_enable,
    output reg        pipeline_flush,
    output reg        fault,
    output reg [7:0]  decimation_ratio
);

    //FSM state registers
    enum reg [2:0] {
        wait_state = 0,
        act_state = 1,
        pipeline_flush_state = 2
    } state = wait_state;

    reg read_data_blanking, disable_fault, arm_fault, clear_fault;
    reg act_state_ended=0;
    reg first_register_write_done = 0;
    wire [31:0] int_readdata; 
    reg [31:0]  latched_address;
    reg [31:0] latched_writedata;
    reg [7:0] slow_fault_counter;
    reg [7:0] slow_fault_threshold;

    RegisterFile Registers(
        .clk(clock),
        .reset(reset),
        .addr_a(simple_bus.sb_address-BASE_ADDRESS),
        .data_a(simple_bus.sb_write_data),
        .we_a(simple_bus.sb_write_strobe),
        .q_a(int_readdata)
    );

    always_comb begin
        if(~reset) begin
            simple_bus.sb_read_data <=0;
        end else begin
            if(read_data_blanking) begin
                simple_bus.sb_read_data <= 0;
            end else begin
                simple_bus.sb_read_data <=int_readdata;
            end
        end
    end

    always_ff@(posedge clock)begin
        if(~reset | disable_fault)begin
            arm_fault <= 0; 
        end else begin
            if(data_in_valid)begin
                arm_fault <= 1;
            end    
        end
        
    end

    always @(posedge clock) begin : fault_trip
        if(~reset | ~arm_fault) begin
            fault <= 0;
            slow_fault_counter <= 0;
        end else begin
            if(trip_high[0] | trip_low[0])begin
                fault <= 1;
            end else if (trip_high[1] | trip_low[1]) begin
                if(slow_fault_counter == slow_fault_threshold-1)begin
                    fault <= 1;
                end else begin
                    slow_fault_counter <= slow_fault_counter +1;    
                end                
            end else if(clear_fault)begin
                fault <= 0;
            end
        end
    end

    //latch bus writes
    always @(posedge clock) begin
        if(~reset) begin
            latched_address<=0;
            latched_writedata<=0;
        end else begin
            if(simple_bus.sb_write_strobe & state == wait_state) begin
                latched_address <= simple_bus.sb_address-BASE_ADDRESS;
                latched_writedata <= simple_bus.sb_write_data;
            end else begin
                latched_address <= latched_address;
                latched_writedata <= latched_writedata;
            end
        end
    end


    // Determine the next state
    always @ (posedge clock) begin
        if (~reset) begin
            simple_bus.sb_ready <= 1'b1;
            read_data_blanking <= 1;
            state <= wait_state;
            comparator_address <=0;
            comparator_threshold <=0;
            comparator_we <=0;
            latch_mode <=0;
            clear_latch <=0;
            filter_address <=0;
            filter_tap <=0;
            filter_we <=0;
            filter_bypass <=0;
            cal_address <=0;
            cal_data <=0;
            cal_we <=0;
            clear_fault<=0;
            disable_fault <= 0;
            gain_enable <=0;
            pipeline_flush <=0;
        end else begin
            case (state)
                wait_state: begin //wait for command
                    clear_fault <= 0;
                    if(simple_bus.sb_write_strobe) begin
                        simple_bus.sb_ready <= 1'b0;
                        state <= act_state;
                    end else if(simple_bus.sb_read_strobe)begin
                        simple_bus.sb_ready <= 0;
                        read_data_blanking <= 0;
                        state <= wait_state;
                    end else begin
                        simple_bus.sb_ready <= 1;
                        read_data_blanking <= 1;
                        state <=wait_state;
                    end
                end
                
                act_state: begin // Act on shadowed write
                    if(act_state_ended) begin
                        state <= pipeline_flush_state;
                    end else begin
                        state <= act_state;
                    end
                end
    
                pipeline_flush_state: begin
                    simple_bus.sb_ready <= 1'b1;
                    state <= wait_state;
                end
            endcase

            //act if necessary
            case (state)
                wait_state: begin 
                    pipeline_flush <= 0;
                end

                act_state: begin
                    case (latched_address)
                        32'h00: begin 
                            comparator_we <= 2'b11; //comp thresh low/low falling
                            comparator_address <= 0;
                            comparator_threshold <=latched_writedata[31:0]; // fast [15:0] slow [31:16]
                            act_state_ended <= 1;
                        end

                        32'h04: begin
                            comparator_we <= 2'b11; //comp thresh --/low raising
                            comparator_address <= 1;
                            comparator_threshold <=latched_writedata[31:0]; // fast [15:0] slow [31:16]
                            act_state_ended <= 1;
                         end
                           
                        32'h08: begin
                            comparator_we <= 2'b11; // comp thresh --/high falling
                            comparator_address <= 2;
                            comparator_threshold <=latched_writedata[31:0]; // fast [15:0] slow [31:16]
                            act_state_ended <= 1;
                        end
                        
                        32'hC: begin
                            comparator_we <= 2'b11; // comp thresh high/high raising
                            comparator_address <= 3;
                            comparator_threshold <=latched_writedata[31:0]; // fast [15:0] slow [31:16]
                            act_state_ended <= 1;
                        end

                        32'h10: begin
                            if(~first_register_write_done) begin
                                cal_we <= 1;
                                cal_address <= 1;
                                cal_data <=latched_writedata[15:0];
                                first_register_write_done <= 1;
                            end else begin
                                cal_we <= 1;
                                cal_address <= 0;
                                cal_data <=latched_writedata[31:16];
                                first_register_write_done <= 0;
                                act_state_ended <= 1;
                            end
                        end

                        32'h14: begin
                            filter_bypass <= latched_writedata[0];
                            latch_mode <= latched_writedata[2:1];
                            clear_latch <= latched_writedata[4:3];
                            cal_data <=latched_writedata[7:5];
                            slow_fault_threshold <= latched_writedata[15:8];
                            clear_fault <= latched_writedata[16];
                            disable_fault <= latched_writedata[17];
                            decimation_ratio <= latched_writedata[31:24];
                            cal_we <= 1;
                            cal_address <= 2;
                            act_state_ended <= 1;
                        end

                        default:
                            act_state_ended <=1;
                    endcase
                end

                pipeline_flush_state: begin
                    cal_we <= 0;
                    filter_we <= 0;
                    comparator_we <= 0;
                    act_state_ended <= 0;
                    pipeline_flush <= 1;
                end

            endcase
        end
    end

endmodule