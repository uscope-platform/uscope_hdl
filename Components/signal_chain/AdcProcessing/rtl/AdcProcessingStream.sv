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


module AdcStreamProcessing #(parameter INPUT_ID = 0, OUTPUT_ID = 0, DATA_WIDTH=16, BASE_ADDRESS = 'h43c00000)(
    input  wire clock,
    input  wire reset,
    //SIMPLEBUS PASSTHROUGH
    Simplebus.slave simple_bus,
    //SIMPLEBUS STREAM IN
    input wire sbs_in_valid,
    output wire sbs_in_ready,
    input wire [DATA_WIDTH-1:0] sbs_in_data,
    input wire [7:0] sbs_in_stream_id,
    //SIMPLEBUS STREAM OUT
    output reg sbs_out_valid,
    input wire sbs_out_ready,
    output reg sbs_out_tlast,
    output reg [DATA_WIDTH-1:0] sbs_out_data,
    output reg [7:0] sbs_out_stream_id
);


    defparam inner_processing.BASE_ADDRESS = BASE_ADDRESS;

    AdcProcessing inner_processing(
        .clock(clock),
        .reset(reset),
        .raw_data_in(sbs_in_data),
        .data_out(sbs_out_data),
        .simple_bus(simple_bus)
    );

    

    assign sbs_in_ready = sbs_out_ready;
    reg[4:0] delay_line;

    always @ (posedge clock) begin
        sbs_out_valid <= delay_line[4];
        delay_line <= {delay_line[3:0], sbs_in_valid};
    end 

endmodule