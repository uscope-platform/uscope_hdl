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

        //Compare low 1
        BFM.write(SB_CHAIN_1_ADDR,0);
        BFM.write(SB_CHAIN_1_ADDR+8'h04,duty-100);
        BFM.write(SB_CHAIN_1_ADDR+8'h08,duty);
        //Compare high 1
        BFM.write(SB_CHAIN_1_ADDR+8'h0C,32'hffffff);
        BFM.write(SB_CHAIN_1_ADDR+8'h10,10001);
        BFM.write(SB_CHAIN_1_ADDR+8'h14,10001);
        //Deadtime
        BFM.write(SB_CHAIN_1_ADDR+8'h18,32'h0);
        BFM.write(SB_CHAIN_1_ADDR+8'h1c,32'h0);
        BFM.write(SB_CHAIN_1_ADDR+8'h20,32'h0);
        //Counter limits
        BFM.write(SB_CHAIN_1_ADDR+8'h24,32'h0);
        BFM.write(SB_CHAIN_1_ADDR+8'h28,10000);
        //Phase Shift
        BFM.write(SB_CHAIN_1_ADDR+8'h2c,32'h0);
        //Output Enables
        BFM.write(SB_CHAIN_1_ADDR+8'h30,32'h3F);
        // Counter control 1
        BFM.write(SB_CHAIN_1_ADDR+8'h38,32'h2);
        
        
                //Compare low 1
        BFM.write(SB_CHAIN_2_ADDR,0);
        BFM.write(SB_CHAIN_2_ADDR+8'h04,0);
        BFM.write(SB_CHAIN_2_ADDR+8'h08,0);
        //Compare high 1
        BFM.write(SB_CHAIN_2_ADDR+8'h0C,32'hffffff);
        BFM.write(SB_CHAIN_2_ADDR+8'h10,32'hffffff);
        BFM.write(SB_CHAIN_2_ADDR+8'h14,32'hffffff);
        //Deadtime
        BFM.write(SB_CHAIN_2_ADDR+8'h18,32'h0);
        BFM.write(SB_CHAIN_2_ADDR+8'h1c,32'h0);
        BFM.write(SB_CHAIN_2_ADDR+8'h20,32'h0);
        //Counter limit
        BFM.write(SB_CHAIN_2_ADDR+8'h24,32'h0);
        BFM.write(SB_CHAIN_2_ADDR+8'h28,10000);
        //Phase Shift
        BFM.write(SB_CHAIN_2_ADDR+8'h2c,32'h0);
        //Output Enables
        BFM.write(SB_CHAIN_2_ADDR+8'h30,32'h3F);
        // Counter control 1
        BFM.write(SB_CHAIN_2_ADDR+8'h38,32'h2);
        // Timebase settings
        
        
        // Timebase settings
        BFM.write(SB_TIMEBASE_ADDR,32'h2428);

    end

endmodule
