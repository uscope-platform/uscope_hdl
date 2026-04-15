

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

module PMP_vsi_tb();
    reg clk, reset;

    axi_lite axi_pwm();
    axi_lite axi_pmp();

    axi_stream modulation_vsi();
    axi_stream vsi_pmp_in();
    axi_stream duty_out();

    reg ext_start, ext_stop;
    wire mod_ready;

    localparam N_CHANNEL_VSI = 6;

    pre_modulation_processor #(
        .CONVERTER_SELECTION("VSI"),
        .PWM_BASE_ADDR(0),
        .N_PWM_CHANNELS(N_CHANNEL_VSI)
    ) UUT_vsi (
        .clock(clk),
        .reset(reset),
        .external_start(ext_start),
        .external_stop(ext_stop),
        .modulation_in(vsi_pmp_in),
        .modulation_out(modulation_vsi),
        .modulator_ready(mod_ready),
        .duty_repeater(duty_out),
        .axi_in(axi_pmp)
    );

    
    wire [15:0] gates_vsi;

    PwmGenerator #(
       .BASE_ADDRESS(0),
       .N_CHANNELS(N_CHANNEL_VSI)
    )  vsi_gen_checker(
        .clock(clk),
        .reset(reset),
        .ext_timebase(0),
        .fault(0),
        .pwm_out(gates_vsi),
        .axi_in(axi_pwm),
        .modulation_in(modulation_vsi)
    );

    wire signed [15:0] vsi_phase_a;
    wire signed [15:0] vsi_phase_b;
    wire signed [15:0] vsi_phase_c;
    wire signed [15:0] vsi_phase_d;
    wire signed [15:0] vsi_phase_e;
    wire signed [15:0] vsi_phase_f;


    assign vsi_phase_a = gates_vsi[0]*1000;
    assign vsi_phase_b = gates_vsi[1]*1000;
    assign vsi_phase_c = gates_vsi[2]*1000;
    assign vsi_phase_d = gates_vsi[3]*1000;
    assign vsi_phase_e = gates_vsi[4]*1000;
    assign vsi_phase_f = gates_vsi[5]*1000;




    ///////////////////////////////////////////////////////////////////////////////////
    //clock generation
    initial clk = 0; 
    always #0.5 clk = ~clk; 

    event reset_done;
    initial begin
        vsi_pmp_in.initialize();
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
        #10 axi_pmp.write('h0, 'h4);
        #10 axi_pmp.write('h4, 1400); //period
        #10 axi_pmp.write('h8, 200);  //duty 0
        #10 axi_pmp.write('hC, 400);  //duty 1
        #10 axi_pmp.write('h10, 600);  //duty 2
        #10 axi_pmp.write('h14, 800);  //dury 3
        #10 axi_pmp.write('h18, 1000);  //dury 4
        #10 axi_pmp.write('h1c, 1200);  //dury 5 
        #50
        ext_start = 1;
        #1 ext_start = 0;
        forever begin
            #500us;
            #10 vsi_pmp_in.write_dest(2, 200 + $urandom_range(0, 100));  //duty 0
            #10 vsi_pmp_in.write_dest(3, 400 + $urandom_range(0, 100));  //duty 1
            #10 vsi_pmp_in.write_dest(4, 600 + $urandom_range(0, 100));  //duty 2
            #10 vsi_pmp_in.write_dest(5, 800 + $urandom_range(0, 100));  //dury 3
            #10 vsi_pmp_in.write_dest(6, 400 + $urandom_range(0, 100));  //duty 1
            #10 vsi_pmp_in.write_dest(7, 600 + $urandom_range(0, 100));  //duty 2
            #10 vsi_pmp_in.write_dest(8, 200 + $urandom_range(0, 100));  //dury 3
        end
    end



endmodule