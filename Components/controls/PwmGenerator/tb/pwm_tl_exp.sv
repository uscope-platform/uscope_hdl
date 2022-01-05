`timescale 1ns / 1ps
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
`include "SimpleBus_BFM.svh"


module pwm_tl_exp();

    reg  clk, reset;
    reg ext_tb=0;
    wire [11:0] pwm;

    wire [31:0] sb_address;
    wire        sb_read_strobe;
    wire        sb_write_strobe;
    wire [31:0] sb_write_data;
    wire        sb_ready;
    wire [31:0] sb_read_data;
    

    wire gate_h_hv;
    wire gate_h_lv;
    wire gate_h_off;
    
    assign gate_h_hv = pwm[10];
    assign gate_h_lv = (pwm[11] ^ pwm[10]);
    assign gate_h_off = pwm[6];
        
    
    wire gate_l_hv;
    wire gate_l_lv;
    wire gate_l_off;
    
    assign gate_l_hv = pwm[2];
    assign gate_l_lv = pwm[1] ^ pwm[2];
    assign gate_l_off = pwm[3];
    
    parameter SB_TIMEBASE_ADDR = 'h43C00000;
    parameter SB_CHAIN_1_ADDR = 'h43C00004;
    parameter SB_CHAIN_2_ADDR = 'h43C00040;

    Simplebus s();

    assign sb_address = s.sb_address;
    assign sb_read_strobe = s.sb_read_strobe;
    assign sb_write_strobe = s.sb_write_strobe;
    assign sb_write_data = s.sb_write_data;
    assign s.sb_ready = sb_ready;
    assign s.sb_read_data = sb_read_data;

    parameter duty = 9000;
    
    PwmGenerator UUT (
        .clock(clk),
        .reset(reset),
        .ext_timebase(ext_tb),
        .pwm_out(pwm),
        .fault(0),
        .sb(s)
    );


    simplebus_BFM BFM;
    
    //clock generation
    initial clk = 0; 
    always #1.25 clk = ~clk; 

    initial begin

        BFM = new(s,2.5);
        //Initial status
        reset <=1'h1;
        #1 reset <=1'h0;
        //TESTS
        #5.5 reset <=1'h1;

        BFM.write(SB_TIMEBASE_ADDR+'h0,'h1100);
        BFM.write(SB_TIMEBASE_ADDR+'h28,'h0);
        BFM.write(SB_TIMEBASE_ADDR+'h3C,'h1);
        BFM.write(SB_TIMEBASE_ADDR+'h34,'h3f);
        BFM.write(SB_TIMEBASE_ADDR+'h2c,'h13f7);
        BFM.write(SB_TIMEBASE_ADDR+'h8,'h4d8);
        BFM.write(SB_TIMEBASE_ADDR+'hc,'h524);
        BFM.write(SB_TIMEBASE_ADDR+'h14,'hf05);
        BFM.write(SB_TIMEBASE_ADDR+'h18,'heeb);
        BFM.write(SB_TIMEBASE_ADDR+'h0,'h1128);
        #50000;
        BFM.write(SB_TIMEBASE_ADDR+'h8,'h2d8);
        BFM.write(SB_TIMEBASE_ADDR+'hc,'h724);
    end

endmodule
