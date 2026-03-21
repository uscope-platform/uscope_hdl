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

`timescale 10ns / 1ns

module pwm_generator_axis_tb();

    reg  clk, reset;
    reg ext_tb=0;
    wire [11:0] pwm;
    
    parameter SB_TIMEBASE_ADDR = 'h43C00000;
    parameter SB_CHAIN_1_ADDR  = 'h43C00100;
    parameter SB_CHAIN_2_ADDR  = 'h43C00200;
    parameter SB_CHAIN_3_ADDR  = 'h43C00300;
    parameter SB_CHAIN_4_ADDR  = 'h43C00400;
    parameter SB_CHAIN_5_ADDR  = 'h43C00500;
    parameter SB_CHAIN_6_ADDR  = 'h43C00600;

    axi_lite axil();
    axi_stream mod_in();

    
    PwmGenerator #(
        .BASE_ADDRESS(32'h43c00000), 
        .N_CHANNELS(1), 
        .COUNTER_WIDTH(16),
        .INITIAL_STOPPED_STATE(0),
        .N_CHAINS(6)
    ) UUT (
        .clock(clk),
        .reset(reset),
        .ext_timebase(ext_tb),
        .axi_in(axil),
        .fault(0),
        .pwm_out(pwm),
        .modulation_in(mod_in)
    );

    always #3 ext_tb = ~ext_tb; 

    //clock generation
    initial clk = 0; 
    always #0.5 clk = ~clk; 

    initial begin
        mod_in.initialize();
        //Initial status
        reset <=1'h1;
        #1 reset <=1'h0;
        //TESTS
        #5.5 reset <=1'h1;

        //Compare low 1
        
        configure_chain(1, 0);
        configure_chain(2, 166);
        configure_chain(3, 332);
        configure_chain(4, 498);
        configure_chain(5, 664);
        configure_chain(6, 830);

        #1 mod_in.write_all(0, 0, 32'h1128);        
    end


    task configure_chain(input logic [31:0] chain, logic [31:0] phase_shift);
        #10 mod_in.write_all(8'h00, chain, 0); 
        #10 mod_in.write_all(8'h04, chain,  500);
        #10 mod_in.write_all(8'h08, chain,  2);
        #10 mod_in.write_all(8'h0C, chain,  0);
        #10 mod_in.write_all(8'h10, chain,  1000);
        #10 mod_in.write_all(8'h14, chain,  phase_shift);
        #10 mod_in.write_all(8'h18, chain,  3);
        #10 mod_in.write_all(8'h1C, chain,  1);
        #10 mod_in.write_all(8'h20, chain,  1);
    endtask
    
    wire pwm_1, pwm_2, pwm_3, pwm_4, pwm_5, pwm_6;
    wire pwm_7, pwm_8, pwm_9, pwm_10, pwm_11, pwm_12;

    assign pwm_1 = pwm[0];
    assign pwm_2 = pwm[1];
    assign pwm_3 = pwm[2];
    assign pwm_4 = pwm[3];
    assign pwm_5 = pwm[4];
    assign pwm_6 = pwm[5];
    assign pwm_7 = pwm[6];
    assign pwm_8 = pwm[7];
    assign pwm_9 = pwm[8];
    assign pwm_10 = pwm[9];
    assign pwm_11 = pwm[10];
    assign pwm_12 = pwm[11];

endmodule
