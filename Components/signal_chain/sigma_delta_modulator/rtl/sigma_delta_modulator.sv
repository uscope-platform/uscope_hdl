// Copyright 2023 Filippo Savi
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

module sigma_delta_modulator #(
    parameter N_CHANNELS = 2,
    INPUT_WIDTH = 16
)(
    input wire clock,
    input wire reset,
    input wire modulator_clock,
    output reg data_out,
    axi_stream.slave data_in
);
    parameter [INPUT_WIDTH-1:0] REFERENCE = 1<<INPUT_WIDTH-1;
    reg modulator_clock_delay;
    reg signed [INPUT_WIDTH-1:0] latched_input = 0;
    reg signed [INPUT_WIDTH+4:0] integrator_1 = 0;
    reg signed [INPUT_WIDTH+4:0] integrator_2 = 0;
    reg signed [INPUT_WIDTH+4:0] comparator_in = 0;
    wire signed [INPUT_WIDTH-1:0] feedback;


    assign feedback = comparator_in > REFERENCE ? REFERENCE : 0;

    assign data_out = comparator_in > REFERENCE;

    assign data_in.ready = 1;

    always_ff @(posedge clock) begin
        if(data_in.valid) latched_input <= data_in.data;
        modulator_clock_delay <= modulator_clock;
        if(modulator_clock & ~modulator_clock_delay)begin
            integrator_1 <= latched_input- feedback + integrator_1;
            integrator_2 <= integrator_2 + integrator_1;
            comparator_in <= integrator_1 + integrator_2 + latched_input;
        end
    end

endmodule