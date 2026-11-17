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

module processing_fault_collector #(
    STICKY_FAULT = 0
)(
    input wire clock,
    input wire reset,
    input wire data_in_valid,
    input wire clear_fault,
    input wire disable_fault,
    input wire [7:0] slow_fault_threshold,
    input adc_processing_types::comparator_control_signal trip_high,
    input adc_processing_types::comparator_control_signal trip_low,
    output reg        fault
);

    reg arm_fault;

    reg [7:0] slow_fault_counter;
    

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
                fault = trip_high.fast | trip_low.fast | trip_high.slow | trip_low.slow;
            end       
        end else begin
            always @(posedge clock) begin : fault_trip
                if(~reset | ~arm_fault) begin
                    fault <= 0;
                    slow_fault_counter <= 0;
                end else begin
                    if(trip_high.fast | trip_low.fast)begin
                        fault <= 1;
                    end else if (trip_high.slow | trip_low.slow) begin
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

endmodule