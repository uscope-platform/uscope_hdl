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
`include "SimpleBus_BFM.svh"
`include "interfaces.svh"
import sock::*;

module AdcProcessing_tb();

    reg  clk, reset,in_valid,out_ready;
    reg [15:0] adc_post_in;
    wire [15:0] adc_post_out;
    wire in_ready,out_valid;
    reg [31:0] sb_read_out;
    string out;
    
    parameter SB_ADDR = 'h43C00000;
	chandle h;

    Simplebus s();

    axi_stream processing_in();
    assign in_ready = processing_in.ready;
    assign processing_in.data = adc_post_in;
    assign processing_in.valid = in_valid;

    axi_stream processing_out();
    assign adc_post_out = processing_out.data;
    assign out_valid = processing_out.valid;
    assign processing_out.ready = out_ready;

    AdcProcessing UUT (
        .clock(clk),
        .reset(reset),
        .data_in(processing_in),
        .data_out(processing_out),
        .simple_bus(s)
    );

    simplebus_BFM BFM;
    
    //clock generation
    initial clk = 0; 
    always #0.5 clk = ~clk; 

    initial begin
    
        if(sock_init() < 0) begin
		    $error("Aww shucks couldn't init the library");
		    $stop();
	    end 

	    //Connect
	    h = sock_open("tcp://localhost:1234");

        BFM = new(s,1);
        
        //Initial status
        reset <=1'h1;
        in_valid <=0;
        out_ready <= 1;
        #1 reset <=1'h0;
        //TESTS
        #5.5 reset <=1'h1;
        adc_post_in[15:0] <= 0;
        //Comparators tresholds
        #8 BFM.write(SB_ADDR+8'h00,32'hA004A004);
        #8 BFM.write(SB_ADDR+8'h04,32'hA004A004);
        #8 BFM.write(SB_ADDR+8'h08,32'hA004A004);
        #8 BFM.write(SB_ADDR+8'h0C,32'hA004A004);


        //Filter taps
        #8 BFM.write(SB_ADDR+8'h10,32'h0B04051B);
        #8 BFM.write(SB_ADDR+8'h14,32'h146D1086);
        #8 BFM.write(SB_ADDR+8'h18,32'h146D15D6);
        #8 BFM.write(SB_ADDR+8'h1C,32'h0B041086);
        #8 BFM.write(SB_ADDR+8'h20,32'h051B);

        //Calibration
        #8 BFM.write(SB_ADDR+8'h24,32'h0);
        #8 BFM.write(SB_ADDR+8'h28,32'h2);

        if(sock_init() < 0) begin
		    $error("Aww shucks couldn't init the library");
		    $stop();
	    end 

        for (int idx = 0; idx<365; idx++) begin
            int in  = sock_readln(h).atoi();
            #1 adc_post_in <= in;
            in_valid <=1;
            out.itoa(adc_post_out);
            if(idx>3) sock_writeln(h,out);
        end
        for (int idx = 356; idx<367; idx++) begin
            adc_post_in<= 0;
            out.itoa(adc_post_out);
            #1 sock_writeln(h,out);
        end
        
        // Done
        sock_close(h);
        sock_shutdown();

        #8 BFM.write(SB_ADDR+8'h10,32'h0B04051B);

        #10 BFM.read(SB_ADDR+8'h10,sb_read_out);

        in_valid <=0;
        
        for (int idx = 0; idx<20; idx++) begin
            #5 adc_post_in <= idx*13;
            in_valid <=1;
            #1 in_valid <=0;
        end

        #10 in_valid <= 1;
        #5 out_ready <= 0;
        #20 out_ready <= 1;
        #1 in_valid <= 0;
        #200;
        #8 BFM.write(SB_ADDR+8'h28,32'h1);
        forever begin
            #10 adc_post_in <=$urandom;
            in_valid <=1;
            #1 in_valid <=0;
        end
    end

endmodule