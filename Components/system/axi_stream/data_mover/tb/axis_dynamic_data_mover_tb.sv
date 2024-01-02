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
`include "axi_lite_BFM.svh"

module axis_dynamic_data_mover_tb();

    reg  clk, reset, start;

    event test_done;
    axi_stream stream_in_req();
    axi_stream stream_in_resp();
    axi_stream stream_out();


    axi_lite axi_master();
    axi_lite_BFM axil_bfm;

    //clock generation
    initial clk = 0; 
    always #0.5 clk = ~clk; 


    reg [31:0] registers_in [3:0];
    reg [31:0] registers_out [3:0] = '{0,0,0,0};

    axis_dynamic_data_mover #(
        .DATA_WIDTH(32),
        .MAX_CHANNELS(4)
    ) UUT (
        .clock(clk),
        .reset(reset),
        .start(start),
        .data_request(stream_in_req),
        .data_response(stream_in_resp),
        .data_out(stream_out),
        .axi_in(axi_master)
    );

    initial begin
        start <= 0;
        axil_bfm = new(axi_master, 1);
        registers_in[0] <= $urandom();
        registers_in[1] <= $urandom();
        registers_in[2] <= $urandom();
        registers_in[3] <= $urandom();
        stream_out.ready <= 1;
        reset <=1'h1;
        #1 reset <=1'h0;
        //TESTS
        #5.5 reset <=1'h1;

        #2 axil_bfm.write('h0, 'h3); // active channels
        #2 axil_bfm.write('h4, 'h020000);
        #2 axil_bfm.write('h8, 'h010001); 
        #2 axil_bfm.write('hc, 'h000002);
        #2 axil_bfm.write('h10, 'h030003); 
        
        #10 start <= 1;
        #1 start <= 0;
        #25 ->test_done;
    end


    always@(posedge clk) begin
        if(stream_in_req.valid) begin
            stream_in_resp.data <= registers_in[stream_in_req.data];
            stream_in_resp.valid <= 1;
        end
        #1 stream_in_resp.valid <= 0;
    end


    always@(posedge clk) begin
        if(stream_out.valid) begin
            registers_out[stream_out.dest] <= stream_out.data; 
        end
    end

    initial begin
        @(test_done);
        assert ((registers_in[0] == registers_out[2]) && (registers_in[1] == registers_out[1]) && registers_in[2] == registers_out[0]) 
        else begin
            $display("Input and output registers do not correspond to what they should be");
            $stop();
        end 
    end

endmodule