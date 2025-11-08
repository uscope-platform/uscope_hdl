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
`include "axi_lite_BFM.svh"
`include "axis_BFM.svh"


module AdcProcessing_denoise_tb();

    reg  clk, reset;
    reg [31:0] sb_read_out;
    wire processed_fault;

    event configuration_done;
    
    axi_stream axis_bfm_if();

    assign processing_in.data = axis_bfm_if.data;
    assign processing_in.valid = axis_bfm_if.valid;
    assign processing_in.dest = axis_bfm_if.dest;
    assign axis_bfm_if.ready = processing_in.ready;

    axi_stream #(
        .DATA_WIDTH(16)
    ) processing_in ();

    axi_stream #(
        .DATA_WIDTH(16)
    ) processing_out();

    axi_stream #(
        .DATA_WIDTH(16)
    ) fast_processing_out();

    assign fast_processing_out.ready = 1;
 

    axi_lite axi_master();
    axi_lite_BFM axil_bfm;


    AdcProcessing #(
        .ENABLE_AVERAGE(1),
        .STICKY_FAULT(0),
        .DENOISING(1'b1)
    ) UUT (
        .clock(clk),
        .reset(reset),
        .data_in(processing_in),
        .filtered_data_out(processing_out),
        .fast_data_out(fast_processing_out),
        .fault(processed_fault),
        .axi_in(axi_master)
    );

    axis_BFM axis_BFM;

    reg [15:0] cal_gain = 1;
    reg [15:0] cal_offset = 4;
    reg signed [15:0] trip_high_f2 = 16'sd29000;
    reg signed [15:0] trip_high_f1 = 16'sd29000;
    reg signed [15:0] trip_low_f1 = -16'sd28999;
    reg signed [15:0] trip_low_f2 = -16'sd29000;

    reg signed [15:0] trip_high_s = 16'sd32767;
    reg signed [15:0] trip_low_s = -16'sd32767;

    //clock generation
    initial clk = 0; 
    always #0.5 clk = ~clk; 

    initial begin
        axil_bfm = new(axi_master, 1);
        axis_BFM = new(axis_bfm_if,1);
        //Initial status
        reset <=1'h1;
        processing_out.ready <= 1;
        #1 reset <=1'h0;
        //TESTS
        #5.5 reset <=1'h1;
        //Comparators
        #10 axil_bfm.write('h00, {trip_low_s, trip_low_f2});
        #10 axil_bfm.write('h04, {trip_low_s, trip_low_f1});
        #10 axil_bfm.write('h08, {trip_high_s, trip_high_f1});
        #10 axil_bfm.write('h0C, {trip_high_s, trip_high_f2});
        //Calibration
        #10 axil_bfm.write('h10, cal_offset);
        #10 axil_bfm.write('h14, cal_offset);
        #10 axil_bfm.write('h18, cal_offset);
        #10 axil_bfm.write('h1c, cal_offset);
        // DENOISING
        #10 axil_bfm.write('h24, {-16'sd5000, 16'sd5000});
        #10 axil_bfm.write('h28, {-16'sd5000, 16'sd5000});
        #10 axil_bfm.write('h2c, {-16'sd5000, 16'sd5000});
        #10 axil_bfm.write('h30, {-16'sd5000, 16'sd5000});
        //CU
        #10 axil_bfm.write('h34, 32'h04010000);
        #10 ->configuration_done;
    end

    parameter data_range = 100;
    parameter fault_data = 6000;


    reg signed [15:0] input_data = 0;
    reg [3:0] channel_ctr = 0;
    reg [1:0] noise_type = 0;

    initial begin
        @(configuration_done);
        forever begin
            #10;
            if(channel_ctr == 3) 
                channel_ctr = 0;
            else 
                channel_ctr++;

            input_data = $random()%data_range;
            noise_type = $urandom()%7;

            if(noise_type == 1)
                input_data = input_data + fault_data;
            if(noise_type == 2)
                input_data = input_data - $signed(fault_data);

            axis_BFM.write_dest(input_data, channel_ctr);
        end    
    end

    reg [15:0] input_streams [3:0];
    reg [15:0] output_streams [3:0];

    always_ff @(posedge clk)begin
        if(processing_in.valid)begin
            input_streams[processing_in.dest] <= processing_in.data;
        end
        if(fast_processing_out.valid)begin
            output_streams[fast_processing_out.dest] <= fast_processing_out.data;
        end
    end

    
    
endmodule