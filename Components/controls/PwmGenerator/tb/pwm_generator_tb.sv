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
`include "SimpleBus_BFM.svh"
`include "interfaces.svh"

module pwm_generator_tb();

    reg  clk, reset;
    reg ext_tb=0;
    wire [11:0] pwm;
    
    parameter SB_TIMEBASE_ADDR = 'h43C00000;
    parameter SB_CHAIN_1_ADDR = 'h43C00004;
    parameter SB_CHAIN_2_ADDR = 'h43C00040;

    Simplebus s();

    PwmGenerator UUT (
        .clock(clk),
        .reset(reset),
        .ext_timebase(ext_tb),
        .sb(s),
        .pwm_out(pwm) 
    );

    simplebus_BFM BFM;
    
    //clock generation
    initial clk = 0; 
    always #0.5 clk = ~clk; 

    realtime period_result = 0;
    integer duty_result = 0;
    integer deadtime_result = 0;
    integer phase_shift_result = 0;

    integer counter_low = 'h1;
    integer counter_high = 'h45;
    integer compare_low = 'h4;
    integer compare_high = 'h20;
    integer deadtime_setting = 'h8;
    integer phase_shift_setting = 'h100;

    initial begin

        BFM = new(s,1);
        //Initial status
        reset <=1'h1;
        #1 reset <=1'h0;
        //TESTS
        #5.5 reset <=1'h1;

        #4 start_output_test();
        output_test_check(period_result,duty_result);

        #100 compare_low <= 'h5;
        compare_high <= 'h22;

        #1 start_online_duty_change_test();
        online_duty_change_test_check(duty_result);

        
        //Test dead time insertion
        #100 start_deadtime_test();
        deadtime_test_check(deadtime_result);

        #100 start_phase_shift_test();
        phase_shift_test_check(phase_shift_result);

        #100 start_sync_test();
        sync_test_check();

    end

    task output_test_check(output realtime period, integer duty);
        real expected_period;
        integer expected_duty;
        realtime first_edge = 0, second_edge =0, third_edge=0;

        @(posedge pwm[0]);
            first_edge = $realtime;
        @(negedge pwm[0]);
            second_edge = $realtime;
        @(posedge pwm[0]);
            third_edge = $realtime;
        
        expected_period = ((counter_high-counter_low)*2+2)*10;
        period = (third_edge-first_edge)*10;
        assert (expected_period == period) else begin
            $fatal(2,"FAILED output period test: the expected period was %e the measured one was %e ", expected_period, period);
        end

        expected_duty = ((compare_high-compare_low)*2+2)/(period/10)*100;
        duty  = $rtoi((second_edge-first_edge)/period*1000);
        assert (expected_duty == duty) else begin
            $fatal(2,"FAILED output duty cycle test: the expected duty cycle was %e the measured one was %e ", expected_duty, duty);
        end
    endtask
    
    task online_duty_change_test_check(output integer duty);
        integer expected_duty;
        realtime first_edge = 0, second_edge =0;

        @(posedge pwm[0]);
            first_edge = $realtime;
        @(negedge pwm[0]);
            second_edge = $realtime;

        expected_duty = ((compare_high-compare_low)*2+2)/(period_result/10)*100;
        duty  = (second_edge-first_edge)/period_result*1000;
        assert (expected_duty == duty) else begin
            $fatal(2,"FAILED output duty cycle test: the expected duty cycle was %e the measured one was %e ", expected_duty, duty);
        end
    endtask

    task deadtime_test_check(output integer deadtime);
        integer expected_deadtime;
        realtime first_edge = 0, second_edge =0;

        @(negedge pwm[3]);
            first_edge = $realtime;
        @(posedge pwm[0]);
            second_edge = $realtime;
        
        
        expected_deadtime = deadtime_setting;
        deadtime  = (second_edge-first_edge);
        assert (expected_deadtime == deadtime) else begin
            $fatal(2,"FAILED deadtime insertion test: the expected deadtime was %e the measured one was %e ", expected_deadtime, deadtime);
        end
    endtask

    task phase_shift_test_check(output integer phase_shift);
        integer expected_phase_shift;
        realtime first_edge = 0, second_edge =0;

        
        @(posedge pwm[0]);
            first_edge = $realtime;
        @(posedge pwm[6]);
            second_edge = $realtime;
        
        expected_phase_shift = phase_shift_setting+2;
        phase_shift  = (second_edge-first_edge);
        assert (expected_phase_shift == phase_shift) else begin
            $fatal(2,"FAILED carrier phase shift test: the expected phase shift was %e the measured one was %e ", expected_phase_shift, phase_shift);
        end
    endtask

    task sync_test_check();
        integer expected_phase_shift;
        realtime first_edge = 0, second_edge =0;
        real phase_shift;
        
        @(posedge pwm[0]);
            first_edge = $realtime;
        @(posedge pwm[6]);
            second_edge = $realtime;
        
        expected_phase_shift = 0;
        phase_shift  = (second_edge-first_edge);
        assert (expected_phase_shift == phase_shift) else begin
            $fatal(2,"FAILED carrier phase shift test: the expected phase shift was %e the measured one was %e ", expected_phase_shift, phase_shift);
        end
    endtask


    task start_output_test();
        //Compare low 1
        BFM.write(SB_CHAIN_1_ADDR+8'h00,compare_low);
        BFM.write(SB_CHAIN_1_ADDR+8'h04,compare_low);
        BFM.write(SB_CHAIN_1_ADDR+8'h08,compare_low);
        //Compare high 1
        BFM.write(SB_CHAIN_1_ADDR+8'h0C,compare_high);
        BFM.write(SB_CHAIN_1_ADDR+8'h10,compare_high);
        BFM.write(SB_CHAIN_1_ADDR+8'h14,compare_high);
        //Deadtime
        BFM.write(SB_CHAIN_1_ADDR+8'h18,deadtime_setting);
        BFM.write(SB_CHAIN_1_ADDR+8'h1c,deadtime_setting);
        BFM.write(SB_CHAIN_1_ADDR+8'h20,deadtime_setting);
        //Counter limits
        BFM.write(SB_CHAIN_1_ADDR+8'h24,counter_low);
        BFM.write(SB_CHAIN_1_ADDR+8'h28,counter_high);
        //Phase Shift
        BFM.write(SB_CHAIN_1_ADDR+8'h2c,32'h0);
        //Output Enables
        BFM.write(SB_CHAIN_1_ADDR+8'h30,32'h3F);

        //Compare low 1
        BFM.write(SB_CHAIN_2_ADDR+8'h00,compare_low);
        BFM.write(SB_CHAIN_2_ADDR+8'h04,compare_low);
        BFM.write(SB_CHAIN_2_ADDR+8'h08,compare_low);
        //Compare high 1
        BFM.write(SB_CHAIN_2_ADDR+8'h0C,compare_high);
        BFM.write(SB_CHAIN_2_ADDR+8'h10,compare_high);
        BFM.write(SB_CHAIN_2_ADDR+8'h14,compare_high);
        //Deadtime 2
        BFM.write(SB_CHAIN_2_ADDR+8'h18,deadtime_setting);
        BFM.write(SB_CHAIN_2_ADDR+8'h1c,deadtime_setting);
        BFM.write(SB_CHAIN_2_ADDR+8'h20,deadtime_setting);
        //Counter limits 2  
        BFM.write(SB_CHAIN_2_ADDR+8'h24,counter_low);
        BFM.write(SB_CHAIN_2_ADDR+8'h28,counter_high);
        //Phase Shift 2
        BFM.write(SB_CHAIN_2_ADDR+8'h2c,32'h10);
        //Output Enables 2
        BFM.write(SB_CHAIN_2_ADDR+8'h30,32'h3F);
        // Counter control 1
        BFM.write(SB_CHAIN_1_ADDR+8'h38,32'h0);
        // Counter control 2
        BFM.write(SB_CHAIN_2_ADDR+8'h38,32'h0);
        BFM.write(SB_CHAIN_1_ADDR+8'h34,32'h0);
        // Timebase settings
        BFM.write(SB_TIMEBASE_ADDR,32'h28);
    endtask

    task start_online_duty_change_test();
        BFM.write(SB_CHAIN_1_ADDR+8'h00,compare_low);
        BFM.write(SB_CHAIN_1_ADDR+8'h04,compare_low);
        BFM.write(SB_CHAIN_1_ADDR+8'h08,compare_low);
        BFM.write(SB_CHAIN_1_ADDR+8'h0c,compare_high);
        BFM.write(SB_CHAIN_1_ADDR+8'h10,compare_high);
        BFM.write(SB_CHAIN_1_ADDR+8'h14,compare_high);
        BFM.write(SB_CHAIN_2_ADDR+8'h00,compare_low);
        BFM.write(SB_CHAIN_2_ADDR+8'h04,compare_low);
        BFM.write(SB_CHAIN_2_ADDR+8'h08,compare_low);
        BFM.write(SB_CHAIN_2_ADDR+8'h0c,compare_high);
        BFM.write(SB_CHAIN_2_ADDR+8'h10,compare_high);
        BFM.write(SB_CHAIN_2_ADDR+8'h14,compare_high);
    endtask

    task start_deadtime_test();
        BFM.write(SB_TIMEBASE_ADDR,32'h8);
        #10 BFM.write(SB_CHAIN_1_ADDR+8'h34,32'h3F);
        BFM.write(SB_CHAIN_2_ADDR+8'h34,32'h3F);
        BFM.write(SB_TIMEBASE_ADDR,32'h28);
    endtask

    task start_phase_shift_test();
        #1 reset <=1'h0;
        #3 reset <=1'h1;

        //Compare low 1
        BFM.write(SB_CHAIN_1_ADDR+8'h00,compare_low);
        BFM.write(SB_CHAIN_1_ADDR+8'h04,compare_low);
        BFM.write(SB_CHAIN_1_ADDR+8'h08,compare_low);
        //Compare high 1
        BFM.write(SB_CHAIN_1_ADDR+8'h0C,compare_high);
        BFM.write(SB_CHAIN_1_ADDR+8'h10,compare_high);
        BFM.write(SB_CHAIN_1_ADDR+8'h14,compare_high);
        //Deadtime
        BFM.write(SB_CHAIN_1_ADDR+8'h18,deadtime_setting);
        BFM.write(SB_CHAIN_1_ADDR+8'h1c,deadtime_setting);
        BFM.write(SB_CHAIN_1_ADDR+8'h20,deadtime_setting);
        //Counter limits
        BFM.write(SB_CHAIN_1_ADDR+8'h24,counter_low);
        BFM.write(SB_CHAIN_1_ADDR+8'h28,counter_high);
        //Phase Shift
        BFM.write(SB_CHAIN_1_ADDR+8'h2c,32'h0);
        //Output Enables
        BFM.write(SB_CHAIN_1_ADDR+8'h30,32'h3F);

        //Compare low 1
        BFM.write(SB_CHAIN_2_ADDR+8'h00,compare_low);
        BFM.write(SB_CHAIN_2_ADDR+8'h04,compare_low);
        BFM.write(SB_CHAIN_2_ADDR+8'h08,compare_low);
        //Compare high 1
        BFM.write(SB_CHAIN_2_ADDR+8'h0C,compare_high);
        BFM.write(SB_CHAIN_2_ADDR+8'h10,compare_high);
        BFM.write(SB_CHAIN_2_ADDR+8'h14,compare_high);
        //Deadtime 2
        BFM.write(SB_CHAIN_2_ADDR+8'h18,deadtime_setting);
        BFM.write(SB_CHAIN_2_ADDR+8'h1c,deadtime_setting);
        BFM.write(SB_CHAIN_2_ADDR+8'h20,deadtime_setting);
        //Counter limits 2  
        BFM.write(SB_CHAIN_2_ADDR+8'h24,counter_low);
        BFM.write(SB_CHAIN_2_ADDR+8'h28,counter_high);
        //Phase Shift 2
        #100 BFM.write(SB_CHAIN_2_ADDR+8'h2c,phase_shift_setting);
        //Output Enables 2
        BFM.write(SB_CHAIN_2_ADDR+8'h30,32'h3F);
        // Counter control 1
        BFM.write(SB_CHAIN_1_ADDR+8'h38,32'h0);
        // Counter control 2
        BFM.write(SB_CHAIN_2_ADDR+8'h38,32'h0);
        BFM.write(SB_TIMEBASE_ADDR,32'h28);
        // Timebase settings
        BFM.write(SB_TIMEBASE_ADDR,32'h28);

    endtask

    task start_sync_test();
        BFM.write(SB_TIMEBASE_ADDR,32'h40);
    endtask

    
endmodule
