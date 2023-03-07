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
`include "axis_BFM.svh"
`include "interfaces.svh"

module pwm_generator_multi_chain_tb();

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

    axis_BFM write_BFM;
    axis_BFM read_req_BFM;
    axis_BFM read_resp_BFM;

    axi_stream read_req();
    axi_stream read_resp();
    axi_stream write();

    axis_to_axil WRITER(
        .clock(clk),
        .reset(reset), 
        .axis_write(write),
        .axis_read_request(read_req),
        .axis_read_response(read_resp),
        .axi_out(axil)
    );
    
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
        .pwm_out(pwm) 
    );

    always #3 ext_tb = ~ext_tb; 

    //clock generation
    initial clk = 0; 
    always #0.5 clk = ~clk; 

    initial begin

        write_BFM = new(write,2.5);
        read_req_BFM = new(read_req, 2.5);
        read_resp_BFM = new(read_resp, 2.5);

        //Initial status
        reset <=1'h1;
        #1 reset <=1'h0;
        //TESTS
        #5.5 reset <=1'h1;

        //Compare low 1
        
        configure_chain(SB_CHAIN_1_ADDR, 0);
        configure_chain(SB_CHAIN_2_ADDR, 166);
        configure_chain(SB_CHAIN_3_ADDR, 332);
        configure_chain(SB_CHAIN_4_ADDR, 498);
        configure_chain(SB_CHAIN_5_ADDR, 664);
        configure_chain(SB_CHAIN_6_ADDR, 830);

        #1 write_BFM.write_dest(32'h1128, SB_TIMEBASE_ADDR);        
    end


    task configure_chain(input logic [31:0] chain_base_address, logic [31:0] phase_shift);
        #1 write_BFM.write_dest(0, chain_base_address+8'h00);
        #1 write_BFM.write_dest(500, chain_base_address+8'h04);
        #1 write_BFM.write_dest(2, chain_base_address+8'h08);
        #1 write_BFM.write_dest(0, chain_base_address+8'h0C);
        #1 write_BFM.write_dest(1000, chain_base_address+8'h10);
        #1 write_BFM.write_dest(phase_shift, chain_base_address+8'h14);
        #1 write_BFM.write_dest(3, chain_base_address+8'h18);
        #1 write_BFM.write_dest(1, chain_base_address+8'h1C);
        #1 write_BFM.write_dest(1, chain_base_address+8'h20);
    endtask
    
endmodule
