

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

module PMP_buck_tb();
    reg clk, reset;

    axi_lite axi_pmp();
    axi_lite axi_pwm();

    axi_stream modulation_buck();
    axi_stream buck_pmp_in();
    axi_stream duty_out();
    reg ext_start, ext_stop;

    localparam N_CHANNEL_BUCK = 1;

    pre_modulation_processor #(
        .CONVERTER_SELECTION("BUCK"),
        .PWM_BASE_ADDR(0),
        .N_CHAINS(6),
        .N_PWM_CHANNELS(N_CHANNEL_BUCK)
    ) UUT_buck (
        .clock(clk),
        .reset(reset),
        .external_start(ext_start),
        .external_stop(ext_stop),
        .modulation_in(buck_pmp_in),
        .modulation_out(modulation_buck),
        .modulator_ready(mod_ready),
        .duty_repeater(duty_out),
        .axi_in(axi_pmp)
    );
    
    wire [15:0] gates_buck;

    PwmGenerator #(
       .BASE_ADDRESS(0),
       .N_CHAINS(6),
       .N_CHANNELS(N_CHANNEL_BUCK)
    )  buck_gen_checker(
        .clock(clk),
        .reset(reset),
        .ext_timebase(0),
        .fault(0),
        .pwm_out(gates_buck),
        .axi_in(axi_pwm),
        .modulation_in(modulation_buck)
    );


    wire status_a, status_b, status_c, status_d, status_e, status_f;

    assign status_a = gates_buck[0];
    assign status_b = gates_buck[1];
    assign status_c = gates_buck[2];
    assign status_d = gates_buck[3];
    assign status_e = gates_buck[4];
    assign status_f = gates_buck[5];

    wire signed [15:0] buck_phase_a;
    wire signed [15:0] buck_phase_b;
    wire signed [15:0] buck_phase_c;
    wire signed [15:0] buck_phase_d;
    wire signed [15:0] buck_phase_e;
    wire signed [15:0] buck_phase_f;


    assign buck_phase_a = gates_buck[0]*1000;
    assign buck_phase_b = gates_buck[1]*1000;
    assign buck_phase_c = gates_buck[2]*1000;
    assign buck_phase_d = gates_buck[3]*1000;
    assign buck_phase_e = gates_buck[4]*1000;
    assign buck_phase_f = gates_buck[5]*1000;
    


    ///////////////////////////////////////////////////////////////////////////////////
    //clock generation
    initial clk = 0; 
    always #0.5 clk = ~clk; 

    event reset_done;
    initial begin
        buck_pmp_in.initialize();
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

    reg [15:0] ps_buck[5:0] ='{
        833,
        667,
        500,
        333,
        167,
        0
    };

    
    initial begin
        @(reset_done);
        #10 axi_pmp.write('h0, 8);
        #10 axi_pmp.write('h4, 1000); //period
        #10 axi_pmp.write('h8, 200);  //duty 1
        #10 axi_pmp.write('hc, 200); //duty 2
        #10 axi_pmp.write('h10, 200); //duty 3
        #10 axi_pmp.write('h14, 200); //duty 4
        #10 axi_pmp.write('h18, 200); //duty 5
        #10 axi_pmp.write('h1c, 200); //duty 6
        #10 axi_pmp.write('h20, 5);   //deadtime
        #10 axi_pmp.write('h24, 6);   //N active phases
        #50
        ext_start = 1;
        #1 ext_start = 0;
        forever begin
            #500us;
        end
    end



endmodule