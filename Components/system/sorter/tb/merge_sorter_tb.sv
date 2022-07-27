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

`timescale 10ns / 1ns
`include "interfaces.svh"
`include "axis_BFM.svh"


parameter max_data_length = 256;

class stimulus;
    rand bit[15:0] length;
    rand bit[15:0] data [max_data_length-1:0];
    constraint length_bounds {length>16 && length<256;}
endclass


module merge_sorter_tb ();

    timeunit 10ns;
    timeprecision 100ps;

    reg clock, reset, start;
    integer data_length = 0;
    event test_start;

    reg [15:0] data_in[max_data_length-1:0];
    reg [15:0] data_out[];

    axi_stream #(.DATA_WIDTH(16)) sorter_in();
    axi_stream sorter_out();

    

    axis_BFM#(16, 32, 32) in_bfm;
    
    merge_sorter #(
        .DATA_WIDTH(16),
        .MAX_SORT_LENGTH(256)
    )UUT(
        .clock(clock),
        .reset(reset),
        .start(start),
        .data_length(data_length),
        .input_data(sorter_in),
        .output_data(sorter_out)
    );

    task generate_test_data(input integer n, output reg [15:0] data[max_data_length-1:0]);
        for (integer y = 0; y<max_data_length ; y +=1 ) begin
            if(y<n) begin
                data[y] = $random();
            end else begin
                data[y] = 0;
            end
        end
    endtask

    task read_sorted_results(input int length, output reg [15:0] data_out[]);
        sorter_out.ready = 1;

        data_out = new[length];

        for(int k = 0; k < max_data_length; k = k + 1) begin
            data_out[k] = 0;
        end
        
        @(posedge sorter_out.valid)
        for(int x = 0; x < length; x = x + 1) begin
            @(negedge clock);
            data_out[x] = sorter_out.data;
            @(posedge clock);
        end
    endtask

    task check_result(input int length, input reg [15:0] data_in[max_data_length-1:0], input reg [15:0] data_out[]);
        reg [15:0] data_expected[];

        data_expected = new [length];
        for(int i = 0; i < length; i = i + 1) begin
            data_expected[i] = data_in[i];
        end
        data_expected.sort();
        output_data_sorting_check:
            assert (data_expected == data_out)
            else
                $fatal("%m The output data stream was not sorted correctly");
    endtask



    initial clock = 0;
    always #0.5 clock = ~clock;


    initial begin
        for(int j = 0; j < max_data_length; j = j + 1) begin
            data_in[j] = 0;
        end
    end



    initial begin
        reset = 0;
        start = 0;
        in_bfm = new(sorter_in, 1);
        #20.5 reset = 0;
        #20 reset = 1;

        ->test_start;
        forever begin
            stimulus stim = new ();
            stim.randomize();
            data_length = stim.length;
            data_in = stim.data;

            for(int i = 0; i < data_length; i = i + 1) begin
                if(i == 0) begin
                    start = 1;
                end else begin
                    start = 0;
                end
                in_bfm.write(data_in[i]);
            end

            read_sorted_results(data_length, data_out);

            #1 check_result(data_length, data_in, data_out);
            #200;
        end
    end





endmodule