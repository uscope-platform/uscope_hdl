// Copyright 2024 Filippo Savi
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
`include "interfaces.svh"


module stream_fault_detector_tb();

    reg  clk, reset, clear_fault;
    wire fault;

    event configuration_done;
    
    axi_lite control_axi();
    axi_stream data_in();


    axi_lite_BFM axil_bfm;
    axis_BFM axis_bfm;

    stream_fault_detector UUT(
        .clock(clk),
        .reset(reset),
        .data_in(data_in),
        .axi_in(control_axi),
        .clear_fault(clear_fault),
        .fault(fault)
    );



    reg signed [15:0] trip_high = 16'sd29000;
    reg signed [15:0] trip_low = -16'sd29000;

    reg signed [15:0] trip_high_s = 16'sd5000;
    reg signed [15:0] trip_low_s = -16'sd5000;

    reg [7:0] slow_trip_duration = 5;

    //clock generation
    initial clk = 0; 
    always #0.5 clk = ~clk; 

    initial begin
        axil_bfm = new(control_axi, 1);
        axis_bfm = new(data_in, 1);
        //Initial status
        data_in.ready = 1;
        clear_fault <= 0;
        reset <=1'h1;
        #1 reset <=1'h0;
        //TESTS
        #5.5 reset <=1'h1;

        #2 axil_bfm.write('h0, trip_low_s);
        #2 axil_bfm.write('h4, trip_high_s);
        #2 axil_bfm.write('h8, slow_trip_duration);


        #2 axil_bfm.write('hc, trip_low);
        #2 axil_bfm.write('h10, trip_high);
        
        ->configuration_done;
    end


    
    initial begin
        @(configuration_done);
        forever begin
            for(int i =0; i<1000; i++)begin
                #5 axis_bfm.write($urandom %1000);
                assert (fault == 0) else begin
                    $fatal(2,"FAILED: The fault signal should be low");
                end
            end 

            #5 axis_bfm.write(60000);
            #10
            assert (fault == 1) else begin
                $fatal(2,"FAILED: The fault signal should be high for fast trip");
            end
            #100 clear_fault <= 1;
            #1 clear_fault <= 0;
            #1000;

            #5 axis_bfm.write(7000);
            #5 axis_bfm.write(7001);
            #5 axis_bfm.write(7002);
            #5 axis_bfm.write(7003);
            #5 axis_bfm.write(7004);
            #10
            assert (fault == 1) else begin
                $fatal(2,"FAILED: The fault signal should be high for slow trip");
            end

            #100 clear_fault <= 1;
            #1 clear_fault <= 0;
            #1000;
        end
        
    end
    
    
endmodule