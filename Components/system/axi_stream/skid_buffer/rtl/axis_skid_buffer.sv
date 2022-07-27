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

`include "interfaces.svh"

module axis_skid_buffer #(
    parameter REGISTER_OUTPUT = 1,
    parameter DATA_WIDTH = 32
) (
    input wire clock,
    input wire reset,
    axi_stream.slave axis_in,
    axi_stream.master axis_out
);


    // If the output is stalled the input needs to be temporarily saved in the skid buffer;

    wire input_data_available;
    assign input_data_available = axis_in.valid && axis_in.ready;
    wire output_stalled;
    assign output_stalled = axis_out.valid && !axis_out.ready;

    reg input_skidding = 0;

    always_ff @(posedge clock) begin
        if (~reset) begin
            input_skidding <= 0;
        end else if (input_data_available && output_stalled) begin
            input_skidding <= 1;
        end else if (axis_out.ready) begin
            input_skidding <= 0;
        end
    end
    

    reg registered_ready_reset;

    always_ff @(posedge clock) begin
        registered_ready_reset <= reset;
    end

    assign axis_in.ready = registered_ready_reset & !input_skidding;

    reg	[DATA_WIDTH-1:0] data_buffer = 0;

    // manage buffer
    always_ff @(posedge clock) begin
        if (~reset) begin
            data_buffer <= 0;
        end else if(axis_in.ready) begin
            data_buffer <= axis_in.data;
        end
    end

    generate
        if (!REGISTER_OUTPUT ) begin
            // Outputs are combinatorially determined from inputs
            assign	axis_out.valid = reset && (axis_in.valid || input_skidding);
    
            always_comb begin
                if (input_skidding) begin
                    axis_out.data = data_buffer;
                end else if(axis_in.valid) begin
                    axis_out.data = axis_in.data;
                end else begin
                    axis_out.data = 0;    
                end
            end
            
        end else begin
            // Register our outputs
            reg	registerd_valid = 0;
    
            always_ff @(posedge clock) begin
                if (~reset) begin
                    registerd_valid <= 0;
                end if (!axis_out.valid || axis_out.ready) begin
                    registerd_valid <= (axis_in.valid || input_skidding); 
                end
            end
            
            assign	axis_out.valid = registerd_valid;
    
            always_ff @(posedge clock) begin
                if (~reset) begin
                    axis_out.data <= 0;
                end else if (!axis_out.valid || axis_out.ready) begin
                    if (input_skidding) begin
                        axis_out.data <= data_buffer;
                    end else begin
                        axis_out.data <= axis_in.data;
                    end
                end
            end
           
        end
    endgenerate

endmodule