

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
`include "axis_BFM.svh"
`include "interfaces.svh"

module PMP_tb();
    reg clk, reset;

    axi_lite ctrl_axi_dab();
    axi_lite ctrl_axi_buck();
    axi_lite axi_pwm_dab();
    axi_lite axi_pwm_buck();

    axis_BFM write_dab_BFM;
    axis_BFM write_buck_BFM;
    axis_BFM read_req_BFM;
    axis_BFM read_resp_BFM;

    axi_stream read_req();
    axi_stream read_resp();
    axi_stream write_dab();
    axi_stream write_buck();

    axis_to_axil writer_dab(
        .clock(clk),
        .reset(reset), 
        .axis_write(write_dab),
        .axis_read_request(read_req),
        .axis_read_response(read_resp),
        .axi_out(ctrl_axi_dab)
    );

    localparam N_CHANNEL_DAB = 6;

    pre_modulation_processor #(
        .CONVERTER_SELECTION("DYNAMIC"),
        .PWM_BASE_ADDR(0),
        .N_PWM_CHANNELS(N_CHANNEL_DAB)
    ) UUT_DAB (
        .clock(clk),
        .reset(reset),
        .axi_in(ctrl_axi_dab),
        .axi_out(axi_pwm_dab)
    );

    PwmGenerator #(
       .BASE_ADDRESS(0),
       .N_CHANNELS(N_CHANNEL_DAB)
    ) dab_gen_checker(
        .clock(clk),
        .reset(reset),
        .ext_timebase(0),
        .fault(0),
        .pwm_out(gates_dab),
        .axi_in(axi_pwm_dab)
    );


    wire [15:0] gates_dab;
    
    wire signed [15:0] pri_a;
    wire signed [15:0] pri_b;
    wire signed [15:0] sec_a;
    wire signed [15:0] sec_b;
     
    assign pri_a = gates_dab[3]*1000;
    assign pri_b = gates_dab[2]*1000;
    assign sec_a = gates_dab[1]*1000;
    assign sec_b = gates_dab[0]*1000;

    wire signed[15:0] pri; 
    wire signed[15:0] sec; 

    assign pri = (pri_a+500)-(500-pri_b);
    assign sec = (sec_a+500)-(500-sec_b);


    // 

    axis_to_axil writer_buck(
        .clock(clk),
        .reset(reset), 
        .axis_write(write_buck),
        .axis_read_request(read_req),
        .axis_read_response(read_resp),
        .axi_out(ctrl_axi_buck)
    );

    localparam N_CHANNEL_BUCK = 6;

    pre_modulation_processor #(
        .CONVERTER_SELECTION("DYNAMIC"),
        .PWM_BASE_ADDR(0),
        .N_PWM_CHANNELS(N_CHANNEL_BUCK)
    ) UUT_buck (
        .clock(clk),
        .reset(reset),
        .axi_in(ctrl_axi_buck),
        .axi_out(axi_pwm_buck)
    );
    
    wire [15:0] gates_buck;

    PwmGenerator #(
       .BASE_ADDRESS(0),
       .N_CHANNELS(N_CHANNEL_BUCK)
    )  buck_gen_checker(
        .clock(clk),
        .reset(reset),
        .ext_timebase(0),
        .fault(0),
        .pwm_out(gates_buck),
        .axi_in(axi_pwm_buck)
    );

    //clock generation
    initial clk = 0; 
    always #0.5 clk = ~clk; 


    initial begin
        write_dab_BFM = new(write_dab,1);
        write_buck_BFM = new(write_buck,1);
        read_req_BFM = new(read_req, 1);
        read_resp_BFM = new(read_resp, 1);
        //Initial status
        reset <=1'h1;
        #1 reset <=1'h0;
        //TESTS
        #5.5 reset <=1'h1;

        #1 write_dab_BFM.write_dest(1000, 'h4); //period
        #1 write_dab_BFM.write_dest(500, 'h8);  //on_time
        #1 write_dab_BFM.write_dest(-500, 'h10); //phase_shift_1
        #300;
        #1 write_dab_BFM.write_dest('h10, 'h0);
        #30000;
        #1 write_dab_BFM.write_dest('h0, 'h0);
        #30000;
        #1 write_dab_BFM.write_dest('h1, 'h0);
        #1 write_dab_BFM.write_dest(400, 'h10); //phase_shift_1
        #1 write_dab_BFM.write_dest(100, 'h14); //phase_shift_2
        #300;
        #1 write_dab_BFM.write_dest('h11, 'h0);
    end

    initial begin
        #6.5 reset <=1'h1;

        #1 write_buck_BFM.write_dest('h4, 'h0);
        #1 write_buck_BFM.write_dest(1000, 'h4); //period
        #1 write_buck_BFM.write_dest(500, 'h8);  //on_time
        #300;
        #1 write_buck_BFM.write_dest('h14, 'h0);
    end

    
    wire signed [15:0] phase_a;
    wire signed [15:0] phase_b;
    wire signed [15:0] phase_c;
    wire signed [15:0] phase_d;


    assign phase_a = gates_buck[0]*1000;
    assign phase_b = gates_buck[1]*1000;
    assign phase_c = gates_buck[2]*1000;
    assign phase_d = gates_buck[3]*1000;



endmodule