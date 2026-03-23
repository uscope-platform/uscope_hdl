

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

module PMP_dab_tb();
    reg clk, reset;

    axi_lite axi_pmp();
    axi_lite axi_pwm();

    reg ext_start, ext_stop;
    
    localparam N_CHANNEL_DAB = 2;

    axi_stream modulation_dab();
    axi_stream dab_pmp_in();
    axi_stream duty_out();

    pre_modulation_processor #(
        .CONVERTER_SELECTION("DAB"),
        .PWM_BASE_ADDR(0),
        .N_PWM_CHANNELS(N_CHANNEL_DAB)
    ) UUT_DAB (
        .clock(clk),
        .reset(reset),
        .external_start(ext_start),
        .external_stop(ext_stop),
        .axi_in(axi_pmp),
        .modulator_ready(mod_ready),
        .duty_repeater(duty_out),
        .modulation_in(dab_pmp_in),
        .modulation_out(modulation_dab)
    );


    wire [15:0] gates_dab;

    PwmGenerator #(
       .BASE_ADDRESS(0),
       .N_CHANNELS(N_CHANNEL_DAB)
    ) dab_gen_checker(
        .clock(clk),
        .reset(reset),
        .ext_timebase(0),
        .fault(0),
        .pwm_out(gates_dab),
        .axi_in(axi_pwm),
        .modulation_in(modulation_dab)
    );


    
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

    //clock generation
    initial clk = 0; 
    always #0.5 clk = ~clk; 


    initial begin
        //Initial status
        reset <=1'h1;
        #1 reset <=1'h0;
        //TESTS
        #5.5 reset <=1'h1;

    end




    ///////////////////////////////////////////////////////////////////////////////////
    //clock generation
    initial clk = 0; 
    always #0.5 clk = ~clk; 

    event reset_done;
    initial begin
        dab_pmp_in.initialize();
        axi_pmp.initialize_master();
        ext_start <= 0;
        ext_stop <= 0;
        //Initial status
        reset <=1'h1;
        #1 reset <=1'h0;
        //TESTS
        #5.5 reset <=1'h1;
        #10 -> reset_done;
    end

    initial begin
        @(reset_done);



        #10 axi_pmp.write('h4, 1000); //period
        #10 axi_pmp.write('h8, 500);  //on_time
        #10 axi_pmp.write('hc, 500);  //on_time
        #10 axi_pmp.write('h10, -500); //phase_shift_1
        #1 axi_pmp.write('h14, 0); //phase_shift_2
        #1 axi_pmp.write('h18, 10); //deadtime
        #10 axi_pmp.write('h0, 0);
        #50
        ext_start = 1;
        #1 ext_start = 0;
        #10ms;
        #1 axi_pmp.write('h0, 'h1);
        #1 axi_pmp.write('h10, 400); //phase_shift_1
        #1 axi_pmp.write('h14, 100); //phase_shift_2
        
    end

endmodule