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
    reg [31:0] users_out [3:0] = '{0,0,0,0};
    reg [31:0] dest_ch_in [3:0] = '{0,0,0,0};
    reg [31:0] dest_ch_out [3:0] = '{0,0,0,0};


    axis_dynamic_data_mover #(
        .DATA_WIDTH(32),
        .MULTICHANNEL_MODE(1),
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

        #2 axil_bfm.write('h4,  'h10026000);
        #2 axil_bfm.write('h8,  'h20017001); 
        #2 axil_bfm.write('hc,  'h30008002);
        #2 axil_bfm.write('h10, 'h40039003);
        
        
        #2 axil_bfm.write('h14, 28);
        #2 axil_bfm.write('h18, 51); 
        #2 axil_bfm.write('h1c, 73);
        #2 axil_bfm.write('h20, 47); 

        #10 start <= 1;
        #1 start <= 0;
        #25 ->test_done;
    end


    always@(posedge clk) begin
        if(stream_in_req.valid) begin
            stream_in_resp.data <= registers_in[stream_in_req.data[15:0]];
            dest_ch_in[stream_in_req.data[15:0]] <= stream_in_req.data[31:16];
            stream_in_resp.valid <= 1;
        end
        #1 stream_in_resp.valid <= 0;
    end


    always@(posedge clk) begin
        if(stream_out.valid) begin
            registers_out[stream_out.dest[15:0]] <= stream_out.data; 
            dest_ch_out[stream_out.dest[15:0]] <= stream_out.dest[31:16];
            users_out[stream_out.dest[15:0]] <= stream_out.user; 
        end
    end

    initial begin
        @(test_done);
        assert ((registers_in[0] == registers_out[2]) && (registers_in[1] == registers_out[1]) && registers_in[2] == registers_out[0]) 
        else begin
            $display("---------------------------------------------------------------------------------------------");
            $display("                                        TEST FAILED");
            $display("              Input and output registers do not correspond to what they should be");
            $display("---------------------------------------------------------------------------------------------");
            $stop();
        end 

        assert ((users_out[0] == 73) && (users_out[1] == 51) && users_out[2] == 28) 
        else begin
            $display("---------------------------------------------------------------------------------------------");
            $display("                                        TEST FAILED");
            $display("                                      wrong user value");
            $display("---------------------------------------------------------------------------------------------");
            $stop();
        end 
        
        assert ((dest_ch_in[0] == 6) && (dest_ch_in[1] == 7) && dest_ch_in[2] == 8) 
        else begin
            $display("---------------------------------------------------------------------------------------------");
            $display("                                        TEST FAILED");
            $display("                       wrong input destination most significant bytes");
            $display("---------------------------------------------------------------------------------------------");
            $stop();
        end 

        assert ((dest_ch_out[0] == 3) && (dest_ch_out[1] == 2) && dest_ch_out[2] == ) 
        else begin
            $display("---------------------------------------------------------------------------------------------");
            $display("                                        TEST FAILED");
            $display("                       wrong output destination most significant bytes");
            $display("---------------------------------------------------------------------------------------------");
            $stop();
        end 

       
            $display("---------------------------------------------------------------------------------------------");
            $display("                                        TEST SUCCESS");
            $display("---------------------------------------------------------------------------------------------");
            $stop();
    end

endmodule