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

module comparator #(parameter DATA_PATH_WIDTH = 16)(
    input wire clock,
    input wire reset,
    input adc_processing_types::comparator_tresholds_register tresholds,
    axi_stream.slave data_in,
    input wire latching_mode,
    input wire clear_latch,
    output reg trip_high,
    output reg trip_low
);


    reg latched = 0;
    
    wire signed[DATA_PATH_WIDTH-1:0] signed_data;
    assign signed_data = $signed(data_in.data);

    always @(posedge clock or negedge reset) begin
        if(~reset)begin
            trip_high <= 0;
            trip_low <= 0;
        end else begin
            if(latching_mode) begin
                if(clear_latch) latched <= 0; 
                if(data_in.valid) begin
                    if(signed_data < tresholds.low_falling) begin
                        trip_low <= 1;
                        latched <=1;
                    end else if(signed_data > tresholds.low_rising & ~latched) begin
                        trip_low <= 0;
                    end
                    if(signed_data > tresholds.high_rising) begin
                        trip_high <= 1;
                        latched <=1;
                    end else if(signed_data < tresholds.high_falling & ~latched) begin
                        trip_high <= 0;
                    end    
                end
            end else begin
                if(data_in.valid) begin
                    if(signed_data < tresholds.low_falling) begin
                        trip_low <= 1;
                    end else if(signed_data > tresholds.low_rising) begin
                        trip_low <= 0;
                    end 
                    if(signed_data > tresholds.high_rising) begin
                        trip_high <=1;
                    end else if(signed_data < tresholds.high_falling) begin
                        trip_high <=0;
                    end
                end
            end
        end
    end



endmodule