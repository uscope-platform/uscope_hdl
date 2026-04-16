

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

    localparam N_CHANNEL_VSI = 12;

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
       .N_CHANNELS(N_CHANNEL_VSI),
       .N_CHAINS(1)
    )  vsi_gen_checker(
        .clock(clk),
        .reset(reset),
        .ext_timebase(0),
        .fault(0),
        .pwm_out(gates_vsi),
        .axi_in(axi_pwm),
        .modulation_in(modulation_vsi)
    );
    wire vsi_phase_a;
    wire vsi_phase_b;
    wire vsi_phase_c;
    wire vsi_phase_d;
    wire vsi_phase_e;
    wire vsi_phase_f;

    wire vsi_phase_g;
    wire vsi_phase_h;
    wire vsi_phase_i;
    wire vsi_phase_l;
    wire vsi_phase_m;
    wire vsi_phase_n;


    assign vsi_phase_a = gates_vsi[0];
    assign vsi_phase_b = gates_vsi[1];
    assign vsi_phase_c = gates_vsi[2];
    assign vsi_phase_d = gates_vsi[3];
    assign vsi_phase_e = gates_vsi[4];
    assign vsi_phase_f = gates_vsi[5];


    assign vsi_phase_g = gates_vsi[6];
    assign vsi_phase_h = gates_vsi[7];
    assign vsi_phase_i = gates_vsi[8];
    assign vsi_phase_l = gates_vsi[9];
    assign vsi_phase_m = gates_vsi[10];
    assign vsi_phase_n = gates_vsi[11];



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

    reg[15:0] address;
    reg[15:0] data;

    int period = 200*N_CHANNEL_VSI+400;

    initial begin
        @(reset_done);
        #10 axi_pmp.write('h0, 'h4);
        #10 axi_pmp.write('h4, period); //period
        for(int i = 0; i< N_CHANNEL_VSI; i++)begin
            #10 axi_pmp.write('h8+4*i, i*200+200);
        end
        #50
        ext_start = 1;
        #1 ext_start = 0;
        forever begin
            #500us;
            for(int i = 0; i< N_CHANNEL_VSI; i++)begin
                address = 2+i;
                data =  (i*200+200+ $urandom_range(0, 100)) % period;
                #10 vsi_pmp_in.write_dest(address,data);
            end
        end
    end



endmodule