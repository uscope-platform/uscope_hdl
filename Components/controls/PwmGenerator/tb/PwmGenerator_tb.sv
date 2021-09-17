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
`include "SimpleBus_BFM.svh"
`include "interfaces.svh"

module PwmGenerator_tb();
    reg  clk, reset;
    reg ext_tb=0;
    wire [11:0] pwm;

    // OUTPUT QUALITY TEST
    // In this test the PWM is configured and the output frequency and duty are measured
    event output_quality_enable;
    // ONLINE DUTY CHANGE TEST
    // In this test the duty cycle is changed online and the new duty measured
    event online_duty_change_enable;
    // DEADTIME TEST
    // In this test automatic deadtime insertion is enabled and verified
    event deadtime_test_enable;
    // PHASE SHIFTER TEST
    // In this test  phase shift between chains is enabled and verified
    event phase_shifter_test_enable;

    logic freq_duty_test_enabled = 0;
    logic online_duty_change_enabled = 0;
    logic deadtime_test_enabled = 0;
    logic phase_shifter_test_enabled = 0;
    parameter SB_TIMEBASE_ADDR = 'h43C00000;
    parameter SB_CHAIN_1_ADDR = 'h43C00004;
    parameter SB_CHAIN_2_ADDR = 'h43C00040;
    realtime first_edge = 0, second_edge =0, third_edge=0;

    Simplebus s();


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
    always #0.5 clk = ~clk; 

    initial begin

        BFM = new(s,1);
        //Initial status
        reset <=1'h1;
        #1 reset <=1'h0;
        //TESTS
        #5.5 reset <=1'h1;

        //Compare low 1
        BFM.write(SB_CHAIN_1_ADDR,32'h4);
        BFM.write(SB_CHAIN_1_ADDR+8'h04,32'h4);
        BFM.write(SB_CHAIN_1_ADDR+8'h08,32'h4);
        //Compare high 1
        BFM.write(SB_CHAIN_1_ADDR+8'h0C,32'h20);
        BFM.write(SB_CHAIN_1_ADDR+8'h10,32'h20);
        BFM.write(SB_CHAIN_1_ADDR+8'h14,32'h20);
        //Deadtime
        BFM.write(SB_CHAIN_1_ADDR+8'h18,32'h7);
        BFM.write(SB_CHAIN_1_ADDR+8'h1c,32'h7);
        BFM.write(SB_CHAIN_1_ADDR+8'h20,32'h7);
        //Counter limits
        BFM.write(SB_CHAIN_1_ADDR+8'h24,32'h1);
        BFM.write(SB_CHAIN_1_ADDR+8'h28,32'h30);
        //Phase Shift
        BFM.write(SB_CHAIN_1_ADDR+8'h2c,32'h0);
        //Output Enables
        BFM.write(SB_CHAIN_1_ADDR+8'h30,32'h3F);

        //Compare low 2
        BFM.write(SB_CHAIN_2_ADDR,32'h4);
        BFM.write(SB_CHAIN_2_ADDR+8'h4,32'h4);
        BFM.write(SB_CHAIN_2_ADDR+8'h8,32'h4);
        //Compare high 2
        BFM.write(SB_CHAIN_2_ADDR+8'h0c,32'h20);
        BFM.write(SB_CHAIN_2_ADDR+8'h10,32'h20);
        BFM.write(SB_CHAIN_2_ADDR+8'h14,32'h20);
        //Deadtime 2
        BFM.write(SB_CHAIN_2_ADDR+8'h18,32'h7);
        BFM.write(SB_CHAIN_2_ADDR+8'h1c,32'h7);
        BFM.write(SB_CHAIN_2_ADDR+8'h20,32'h7);
        //Counter limits 2  
        BFM.write(SB_CHAIN_2_ADDR+8'h24,32'h1);
        BFM.write(SB_CHAIN_2_ADDR+8'h28,32'h30);
        //Phase Shift 2
        BFM.write(SB_CHAIN_2_ADDR+8'h2c,32'h10);
        //Output Enables 2
        BFM.write(SB_CHAIN_2_ADDR+8'h30,32'h3F);
        // Counter control 1
        BFM.write(SB_CHAIN_1_ADDR+8'h38,32'h0);
        // Counter control 2
        BFM.write(SB_CHAIN_2_ADDR+8'h38,32'h0);
        BFM.write(SB_CHAIN_1_ADDR+8'h34,32'h3F);
        // Timebase settings
        BFM.write(SB_TIMEBASE_ADDR,32'h28);


        

        #4 ->output_quality_enable;

        // Trigger the test process to start monitoring the output
        freq_duty_test_enabled <= 1;
        
        // Test online duty cycle change
        #250 BFM.write(SB_CHAIN_1_ADDR,32'h5);
        BFM.write(SB_CHAIN_1_ADDR+8'h04,32'h5);
        BFM.write(SB_CHAIN_1_ADDR+8'h08,32'h5);
        
        BFM.write(SB_CHAIN_1_ADDR+8'h0c,32'h22);
        BFM.write(SB_CHAIN_1_ADDR+8'h10,32'h22);
        BFM.write(SB_CHAIN_1_ADDR+8'h14,32'h22);
        BFM.write(SB_CHAIN_2_ADDR,32'h5);
        BFM.write(SB_CHAIN_2_ADDR+8'h04,32'h5);
        BFM.write(SB_CHAIN_2_ADDR+8'h08,32'h5);
        BFM.write(SB_CHAIN_2_ADDR+8'h0c,32'h22);
        BFM.write(SB_CHAIN_2_ADDR+8'h10,32'h22);
        BFM.write(SB_CHAIN_2_ADDR+8'h14,32'h22);
        #30 online_duty_change_enabled <= 1;
        
        //Test dead time insertion
        #300 BFM.write(SB_CHAIN_1_ADDR+8'h34,32'h3F);
        BFM.write(SB_CHAIN_2_ADDR+8'h34,32'h3F);
        #300 deadtime_test_enabled <= 1;
        first_edge <= 0;
        second_edge <= 0;
        third_edge <= 0;

        #300 BFM.write(SB_TIMEBASE_ADDR,32'h8);
        #100 BFM.write(SB_CHAIN_2_ADDR+8'h2c,32'h100);
        BFM.write(SB_TIMEBASE_ADDR,32'h28);
        phase_shifter_test_enabled <= 1;
        first_edge <= 0;
        second_edge <= 0;
    end

    realtime period = 0;
    real duty = 0;
    logic freq_test_result, duty_test_result, deadtime_duration_result, phase_shift_result;

    // TEST OUTPUT FREQUENCY AND DUTY
    always@(posedge pwm) begin
        if(freq_duty_test_enabled) begin
            first_edge = second_edge;
            second_edge = $realtime;
        
            if(first_edge != 0) begin
                freq_duty_test_enabled = 0;
                period = (second_edge-first_edge)*10;
                duty  = $rtoi((third_edge-first_edge)/period*1000);
                
                first_edge = 0;
                second_edge = 0;
                third_edge = 0;
            end
        end
    end

    always@(negedge pwm) begin
        if(freq_duty_test_enabled) begin
            third_edge = $realtime;
        end
    end

    always@(negedge freq_duty_test_enabled) begin
        FREQUENCY_TEST: assert (period == 40*48) begin //TODO: replace with dynamically calculated value
            freq_test_result = 1;
        end else begin
            freq_test_result = 0;
        end

        DUTY_TEST: assert (duty == 60) begin //TODO: replace with dynamically calculated value
            duty_test_result = 1;
        end else begin
            duty_test_result = 0;
        end
    end

    //TEST ONLINE DUTY CHANGE
    always@(posedge pwm) begin
        if(online_duty_change_enabled) begin
            first_edge = second_edge;
            second_edge = $realtime;
        end
        if(first_edge != 0) begin
            online_duty_change_enabled = 0;
            period = (second_edge-first_edge)*10;
            duty  = $rtoi((third_edge-first_edge)/period*1000);
        end
    end

    logic online_duty_test_result;

    always@(negedge pwm) begin
        if(online_duty_change_enabled) begin
            third_edge = $realtime;
        end
    end

    always@(negedge online_duty_change_enabled) begin
        ONLINE_DUTY_TEST: assert (duty == 58) begin //TODO: replace with dynamically calculated value
            online_duty_test_result = 1;
        end else begin
            online_duty_test_result = 0;
        end
    end


    //Test deadtime insertion
    logic [23:0] first_pwm = 0;
    logic [23:0] second_pwm = 0;
    logic [23:0] third_pwm = 0;
    logic [23:0] fourth_pwm = 0;
    realtime fourth_edge = 0;
    always@(pwm) begin
        if(deadtime_test_enabled) begin
            if(first_edge != 0) begin
                deadtime_test_enabled <= 0;
            end
            first_edge <= second_edge;
            first_pwm <= second_pwm;
            second_edge <= third_edge;
            second_pwm <= third_pwm;
            third_edge <= fourth_edge;
            third_pwm <= fourth_pwm;
            fourth_edge <= $realtime;
            fourth_pwm <= pwm;
        end
    end
    
    real deadtime_duration;
    always@(negedge deadtime_test_enabled) begin
        third_pwm <= 0;
        deadtime_duration = third_edge-second_edge;    
        if(second_pwm==0 && first_pwm != 0 && fourth_edge != 0 && deadtime_duration < 95) begin
            deadtime_duration_result <= 1;
        end else deadtime_duration_result <= 0;
    end

    //Test counter phase shifter
    real shift;
    always@(posedge clk) begin
        if(phase_shifter_test_enabled)begin
            if(pwm[0] & first_edge == 0) first_edge <=  $realtime;
            if(pwm[6] & second_edge == 0) second_edge <= $realtime;
            if(pwm[6] & second_edge == 0) phase_shifter_test_enabled <= 0;
        end
    end
     
    always@(negedge phase_shifter_test_enabled) begin
        shift = second_edge-first_edge;
        if(shift == 256) begin
            phase_shift_result <= 1;
        end else begin
            phase_shift_result <= 0;
        end
    end
    
endmodule