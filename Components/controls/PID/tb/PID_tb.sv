

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

module PID_tb();
    reg  clk, reset;

    reg signed [15:0] reference;
    reg signed [15:0] feedback;
    reg signed [15:0] PID_out;
    reg ref_v, fed_v,out_ready;

    Simplebus s();


    simplebus_BFM BFM;
    
    //clock generation
    initial clk = 0; 
    always #0.5 clk = ~clk; 

    defparam uut.BASE_ADDRESS = 0;
    defparam uut.INPUT_DATA_WIDTH = 16;
    PID uut (
        .clock(clk),
        .reset(reset),
        .reference_valid(ref_v),
        .feedback_valid(fed_v),
        .sb(s),
        .reference(reference),
        .feedback(feedback),
        .PID_out(PID_out),
        .out_ready(out_ready)
    );
    initial begin

        BFM = new(s,1);
        //Initial status
        reset <=1'h1;
        reference <= 0;
        feedback <= 0;
        fed_v <= 0;
        ref_v <= 0;
        out_ready <= 1;
        #1 reset <=1'h0;
        //TESTS
        #5.5 reset <=1'h1;


        //Compare low 1
        #8 BFM.write(32'h00,32'h0);
        BFM.write(32'h04,32'h1);
        BFM.write(32'h08,32'h0);
        BFM.write(32'h0C,32'h0);
        BFM.write(32'h10,32767);
        BFM.write(32'h14,0);
        BFM.write(32'h18,32767);
        BFM.write(32'h1C,0);
        BFM.write(32'h20,0);
    
        reference <= 0;
        feedback <= 19;
        fed_v <= 1;
        ref_v <= 1;
        #10 out_ready <= 0;
        #5 fed_v <= 0;
        #10 out_ready <= 1;
        #90 feedback <= 21;
        fed_v <= 1;
        

        forever begin
            #10 feedback <= $urandom;
                feedback[15] <= 0;
                fed_v <= 1;
                #1 fed_v <= 0;
        end


    end

endmodule