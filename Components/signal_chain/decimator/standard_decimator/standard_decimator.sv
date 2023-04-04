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
`timescale 1 ps / 1 ps
`include "interfaces.svh"

module standard_decimator #(
    parameter MAX_DECIMATION_RATIO = 16, 
    DATA_WIDTH= 16, 
    AVERAGING=0,
    AVERAGING_DIVISOR=2,
    N_CHANNELS = 1
    )(
    input wire clock,
    input wire reset,
    axi_stream.slave data_in,
    axi_stream.master data_out,
    input wire [$clog2(MAX_DECIMATION_RATIO)-1:0] decimation_ratio
);

    reg [$clog2(MAX_DECIMATION_RATIO)-1:0] decimation_counter[N_CHANNELS-1:0];
    
    reg [(DATA_WIDTH+$clog2(MAX_DECIMATION_RATIO))-1:0] average_accumulator [N_CHANNELS-1:0];
    
    wire [(DATA_WIDTH+$clog2(MAX_DECIMATION_RATIO))-1:0] extended_data_in;

    assign data_in.ready = data_out.ready;
    assign extended_data_in = {{$clog2(MAX_DECIMATION_RATIO){data_in.data[DATA_WIDTH-1]}}, data_in.data};
    
    initial begin
        for(integer i = 0; i<N_CHANNELS; i++)begin
            average_accumulator[i] <= 0;
            decimation_counter[i] <= 0;
        end
    end
    
    generate
        if(AVERAGING==1) begin
            always_ff @(posedge clock) begin
                if(~reset)begin
                    data_out.data <= 0;
                    data_out.valid <= 0;
                    data_out.dest <= 0;
                    for(integer i = 0; i<N_CHANNELS; i++)begin
                        average_accumulator[i] <= 0;
                        decimation_counter[i] <= 0;
                    end
                end else begin
                    if(data_out.valid) data_out.valid <= 0;
                    if(data_in.valid) begin
                        average_accumulator[data_in.dest] <= average_accumulator[data_in.dest] + extended_data_in;
                        decimation_counter[data_in.dest] <= decimation_counter[data_in.dest]+1;
                        if((decimation_counter[data_in.dest] == decimation_ratio-1 )| decimation_ratio ==0)begin
                            data_out.data <= (average_accumulator[data_in.dest] + extended_data_in) >>> AVERAGING_DIVISOR;
                            average_accumulator[data_in.dest] <= 0;
                            data_out.dest <= data_in.dest;
                            data_out.valid <= 1;
                            decimation_counter[data_in.dest] <= 0;
                        end 
                    end
                end
            end
        end else begin
            always_ff @(posedge clock) begin
                if(~reset)begin
                    data_out.data <= 0;
                    data_out.valid <= 0;
                    data_out.dest <= 0;
                    for(integer i = 0; i<N_CHANNELS; i++)begin
                        decimation_counter[i] <= 0;
                    end
                end else begin
                    if(data_out.valid) data_out.valid <= 0;
                    if(data_in.valid) begin
                        decimation_counter[data_in.dest] <= decimation_counter[data_in.dest] +1;
                        if((decimation_counter[data_in.dest] == decimation_ratio-1 )| decimation_ratio ==0)begin
                            data_out.data <= data_in.data;
                            data_out.dest <= data_in.dest;
                            data_out.valid <= 1;
                            decimation_counter[data_in.dest] <= 0;
                        end 
                    end
                end
            end

        end
    endgenerate



    





endmodule