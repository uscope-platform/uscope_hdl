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
`timescale 10 ns / 1 ns
`include "axi_lite_BFM.svh"


module CIC_filter_tb();

    reg  clock, reset;

    axi_stream #(.DATA_WIDTH(16)) filter_in();
    axi_stream filter_out();

    event config_done;
    localparam STIMULUS_SIZE = 2048;
    localparam DECIMATION_RATIO = 16;

    reg [15:0] stimulus [STIMULUS_SIZE-1:0];
    reg [31:0] check [STIMULUS_SIZE/DECIMATION_RATIO-1:0];
    reg [31:0] out_data [STIMULUS_SIZE/DECIMATION_RATIO-3:0] = '{default:0};

    CIC_filter #(
        .N_STAGES(3),
        .PROCESSING_RESOLUTION(28)
    ) UUT(
        .clock(clock),
        .reset(reset),
        .downsampling_ratio(DECIMATION_RATIO),
        .data_in(filter_in),
        .data_out(filter_out)
    );

    always begin
        clock = 1'b1;
        #0.5 clock = 1'b0;
        #0.5;
    end


    initial begin
        $readmemh("stim.mem", stimulus);
        $readmemh("check.mem", check);
        filter_in.initialize();
        filter_out.ready <= 1;
        reset <=1'h1;
        #10 reset <=1'h0;
        //TESTS
        #20.5 reset <=1'h1;
        #50;
        ->config_done;
    end

    integer stim_ctr;
    initial begin
        stim_ctr = 0;
        @(config_done);
        forever begin
            if(stim_ctr == STIMULUS_SIZE) $finish();
            filter_in.write(stimulus[stim_ctr]);
            stim_ctr = stim_ctr+1;
            #10;
        end
    end

    integer res_ctr = 0;
    always_ff @(posedge clock)begin
        if(filter_out.valid)begin
            out_data[res_ctr] <= filter_out.data;
            res_ctr <= res_ctr+1;
            assert (filter_out.data == check[res_ctr]) 
            else begin
                $display(
                "ERROR: EXPECTED FILTER OUTPUT : %d |RTL CALCULATED: %d",
                $signed(check[res_ctr]),
                $signed(filter_out.data)
            );
            end
            
        end
    end
    
endmodule