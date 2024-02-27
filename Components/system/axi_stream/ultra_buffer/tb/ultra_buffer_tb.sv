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

module ultra_buffer_tb();

    reg  clock, reset, start;

    event test_done;
    axi_stream stream_in();
    axi_stream stream_out();


    //clock generation
    initial clock = 0; 
    always #0.5 clock = ~clock; 

    reg trigger = 0;
    wire full;

    ultra_buffer #(
        .ADDRESS_WIDTH(13),
        .IN_DATA_WIDTH(32),
        .DEST_WIDTH(16),
        .USER_WIDTH(16)
    )UUT(
        .clock(clock),
        .reset(reset),
        .enable(1),
        .packet_length(6144),
        .trigger(trigger),
        .trigger_point(300),
        .full(full),
        .in(stream_in),
        .out(stream_out)
    );

    

    event config_done;

    initial begin
        reset <=1'h1;
        #1 reset <=1'h0;
        //TESTS
        #5.5 reset <=1'h1;
        #10;
        ->config_done;
        forever begin
            #500 trigger <= 1;
            #1 trigger <= 0;
            #35000;
        end
    end 

    reg [15:0] data_ctr = 0;

    initial begin
        stream_in.valid <= 0;
        stream_in.data <= 0;
        stream_in.dest <= 0;
        stream_in.user <= 0;
        @(config_done);
        forever begin
            wait(stream_in.ready == 1);
            stream_in.valid <= 1;
            stream_in.data <= data_ctr;
            stream_in.dest <= 5;
            stream_in.user <= 'h28;
            data_ctr <= data_ctr + 1;
            #1 stream_in.valid <= 0;
            #3;
        end
    end
    

    initial begin
    
        stream_out.ready <= 1;
        #0.5;
        #18000;
        stream_out.ready <= 0;
        # 5;
        stream_out.ready <= 1;
    end

endmodule