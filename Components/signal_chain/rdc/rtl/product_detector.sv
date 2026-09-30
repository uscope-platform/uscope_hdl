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

module product_detector #(
    parameter int N_CHANNELS = 2
)(
    input wire clock,
    input wire reset,
    axi_stream.slave analog_in,
    axi_stream.slave excitation
);

axi_stream #(.DATA_WIDTH($bits(analog_in.data))) sin();
axi_stream #(.DATA_WIDTH($bits(analog_in.data))) cos();
axi_stream #(.DATA_WIDTH(2*$bits(analog_in.data))) sin_hf();
axi_stream #(.DATA_WIDTH(2*$bits(analog_in.data))) cos_hf();

reg [$bits(excitation.data)-1:0] latched_excitation;
reg signed [2*$bits(analog_in.data)-1:0] sin_product;
reg signed [2*$bits(analog_in.data)-1:0] cos_product;

assign analog_in.ready = 1;
assign excitation.ready = 1;

always_ff@(posedge clock)begin
    if(excitation.valid) latched_excitation <= excitation.data;
    sin_hf.valid <= 0;
    cos_hf.valid <= 0;

    if(analog_in.valid)begin
        if(analog_in.dest == 0) begin
            sin_hf.data <= $signed(latched_excitation) * $signed(analog_in.data);
            sin_hf.valid <= 1;
        end
        
        if(analog_in.dest == 1) begin
            cos_hf.data <= $signed(latched_excitation) * $signed(analog_in.data);
            cos_hf.valid <= 1;
        end
    end
end

CIC_filter #(
    .N_STAGES(2),
    .MAX_RATIO(32)
)sin_lpf(
    .clock(clock),
    .reset(reset),
    .downsampling_ratio(16),
    .data_in(sin_hf),
    .data_out(sin)
);
    

CIC_filter #(
    .N_STAGES(2),
    .MAX_RATIO(32)
)cos_lpf(
    .clock(clock),
    .reset(reset),
    .downsampling_ratio(16),
    .data_in(cos_hf),
    .data_out(cos)
);
    

endmodule