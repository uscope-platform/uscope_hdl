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

module AdcProcessingControlUnit #(parameter BASE_ADDRESS = 'h43c00000, STICKY_FAULT = 0, DATA_PATH_WIDTH = 16)(
    input wire clock,
    input wire reset,
    input wire data_in_valid,
    Simplebus.slave simple_bus,
    // COMPARATORS
    output reg signed [DATA_PATH_WIDTH-1:0] comparator_thresholds [0:7],
    output reg [1:0]  latch_mode,
    output reg [1:0]  clear_latch,
    input wire [1:0]  trip_high,
    input wire [1:0]  trip_low,
    // CALIBRATION
    output reg signed [DATA_PATH_WIDTH-1:0] calibrator_coefficients [2:0],
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

    generate
        if(STICKY_FAULT==0) begin
            always_comb begin
                fault <= trip_high[0] | trip_low[0] | trip_high[1] | trip_low[1];
            end       
        end else begin
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
        end
    endgenerate

    
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
            simple_bus.sb_read_valid <= 1'b0;
            read_data_blanking <= 1;
            state <= wait_state;
            latch_mode <=0;
            clear_latch <=0;
            clear_fault<=0;
            disable_fault <= 0;
            gain_enable <=0;
            pipeline_flush <=0;
        end else begin
            case (state)
                wait_state: begin //wait for command
                    clear_fault <= 0;
                    simple_bus.sb_read_valid <= 1'b0;
                    if(simple_bus.sb_write_strobe) begin
                        simple_bus.sb_ready <= 1'b0;
                        state <= act_state;
                    end else if(simple_bus.sb_read_strobe)begin
                        simple_bus.sb_ready <= 1'b0;
                        read_data_blanking <= 1'b0;
                        simple_bus.sb_read_valid <= 1'b1;
                        state <= wait_state;
                    end else begin
                        simple_bus.sb_ready <= 1'b1;
                        read_data_blanking <= 1'b1;
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
                            //comp thresh low/low falling
                            comparator_thresholds[0] <= latched_writedata[15:0];
                            comparator_thresholds[4] <= latched_writedata[31:16];
                            act_state_ended <= 1;
                        end

                        32'h04: begin
                            //comp thresh --/low raising
                            comparator_thresholds[1] <= latched_writedata[15:0];
                            comparator_thresholds[5] <= latched_writedata[31:16];
                            act_state_ended <= 1;
                         end
                           
                        32'h08: begin
                            // comp thresh --/high falling
                            comparator_thresholds[2] <= latched_writedata[15:0];
                            comparator_thresholds[6] <= latched_writedata[31:16];
                            act_state_ended <= 1;
                        end
                        
                        32'hC: begin
                            // comp thresh high/high raising
                            comparator_thresholds[3] <= latched_writedata[15:0];
                            comparator_thresholds[7] <= latched_writedata[31:16];
                            act_state_ended <= 1;
                        end

                        32'h10: begin
                            calibrator_coefficients[1] <= latched_writedata[15:0];
                            calibrator_coefficients[0] <= latched_writedata[31:16];
                            act_state_ended <= 1;
                        end

                        32'h14: begin
                            latch_mode <= latched_writedata[2:1];
                            clear_latch <= latched_writedata[4:3];
                            calibrator_coefficients[2] <= latched_writedata[7:5];
                            slow_fault_threshold <= latched_writedata[15:8];
                            clear_fault <= latched_writedata[16];
                            disable_fault <= latched_writedata[17];
                            decimation_ratio <= latched_writedata[31:24];
                            act_state_ended <= 1;
                        end

                        default:
                            act_state_ended <=1;
                    endcase
                end

                pipeline_flush_state: begin
                    act_state_ended <= 0;
                    pipeline_flush <= 1;
                end

            endcase
        end
    end

endmodule