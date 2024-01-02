

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
`include "interfaces.svh"

module programmable_sequencer_tb();
    reg clk, reset;

    always begin
        clk = 1'b1;
        #0.5 clk = 1'b0;
        #0.5;
    end

    axi_lite axi_master();
    axi_lite_BFM axil_bfm;


    wire [7:0] start_step;
    reg [7:0] step_done = 0;
    reg enable = 0;

    programmable_sequencer #(
        .MAX_STEPS(8),
        .COUNTER_WIDTH(32)
    )UUT(
        .clock(clk),
        .reset(reset),
        .enable(enable),
        .step_done(step_done),
        .step_start(start_step),
        .axi_in(axi_master)
    );



    initial begin  
        axil_bfm = new(axi_master, 1);
        //Initial status
        reset <=1'h1;
        #10 reset <=1'h0;
        //TESTS
        #20.5 reset <=1'h1;

        #50;
        #2 axil_bfm.write('h0, 'h108);
        #2 axil_bfm.write('h4, 0);
        #2 axil_bfm.write('h8, 4); 

        #2 axil_bfm.write('hC,  4); 
        #2 axil_bfm.write('h10, 3); 
        #2 axil_bfm.write('h14, 5); 
        #2 axil_bfm.write('h18, 2); 
        #2 axil_bfm.write('h1C, 6); 
        #2 axil_bfm.write('h20, 1); 
        #2 axil_bfm.write('h24, 7); 
        #2 axil_bfm.write('h28, 0); 

        #20 enable <= 1;
        #5 enable <= 0;

        #500 axil_bfm.write('h0, 'h8);
        #5 enable <= 1;
        #1 enable <= 0;
    end
    
    reg in_step = 0;
    reg [2:0] step_duration = 0;
    always_ff@(posedge clk) begin
        step_done <= 0;
        if(|start_step)begin
            in_step <= 1;
            step_duration<= 1;
        end

        if(in_step)begin
            if(step_duration == 5) begin
                step_done <= 'hFF;
                step_duration <= 0;
                in_step <= 0;
            end else begin
                step_duration <= step_duration+1;
            end
        end 
    end

endmodule