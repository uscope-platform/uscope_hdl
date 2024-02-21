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

module axis_data_mover_tb();



    reg  clock, reset, start;

    event test_done;
    axi_stream stream_in();
    axi_stream stream_out();

    //clock generation
    initial clock = 0; 
    always #0.5 clock = ~clock; 


    ultra_buffer #(
        .DATA_WIDTH(32),
        .USER_WIDTH(16),
        .DEST_WIDTH(16)
    )UUT(
        .clock(clock),
        .reset(reset),
        .enable(1),
        .in(stream_in),
        .out(stream_out)
    );

    initial begin
        stream_out.ready <= 1;
        reset <=1'h1;
        #1 reset <=1'h0;
        //TESTS
        #5.5 reset <=1'h1;
    end


    always@(posedge clk) begin
        stream_in.valid <= 1;
        stream_in.data <= $urandom();
        stream_in.dest <= $urandom()%5;
        stream_in.user <= 'h28;
        #1 stream_in.valid <= 0;
        #3;
    end

endmodule