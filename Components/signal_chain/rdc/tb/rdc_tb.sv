// Copyright 2021 Filippo Savi
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


module rdc_tb();

    reg clock, reset, enable, excitation_stream, res_sample;
    reg mod_trigger = 0;

    always begin
        clock = 1'b1;
        #0.5 clock = 1'b0;
        #0.5;
    end

    axi_stream #(.DATA_WIDTH(16)) analog_in();
        
    rdc UUT (
        .clock(clock),
        .reset(reset),
        .excitation(excitation_stream),
        .analog_in(analog_in)
    );
    
    always_ff @(posedge clock)begin
        mod_trigger <= ~mod_trigger;
    end

    real resolver_angle = 0;

    real v_excitation;

    exc_filter exc_flt (
        .clk_sample(mod_trigger),
        .dac_bitstream(excitation_stream),
        .v_excitation(v_excitation)
    );


    resolver res_emu(  
        .clock(clock),
        .reset(reset),
        .v_excitation(v_excitation),
        .sample(res_sample),
        .angle(resolver_angle),
        .analog_out(analog_in)
    );


    reg [63:0] v_excitation_b;
      
    always_ff @(posedge clock ) begin
        v_excitation_b <= $realtobits(v_excitation);
    end
      

    event test_start;
    initial begin
        analog_in.initialize();
        reset <=1'h1;
        #10 reset <=1'h0;
        //TESTS
        #20.5 reset <=1'h1;

        #50.5;
        ->test_start;
    end

    localparam pi = 3.14;
    localparam angle_incr = 1/180.0*pi;

    initial begin
        enable <= 1;
        res_sample = 0;
        @(test_start);
        forever begin
            resolver_angle = resolver_angle + angle_incr;
            if(resolver_angle>2*pi) resolver_angle = 0;
            res_sample <= 1;
            #1 res_sample <= 0;
            #3999;
        end
    end
    

    reg [15:0] res_sin;
    reg [15:0] res_cos;
    reg [63:0] res_angle;


    always_ff @(posedge clock)begin
        if(analog_in.valid)begin
            if(analog_in.dest == 0) res_sin <= analog_in.data;
            if(analog_in.dest == 1) res_cos <= analog_in.data;
        end
        res_angle <= $realtobits(resolver_angle);
    end



endmodule
