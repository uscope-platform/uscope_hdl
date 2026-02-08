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
`include "axi_lite_BFM.svh"


module sigma_delta_modulator_tb();

    reg  clock, modulator_clock, reset;

    always begin
        clock = 1'b1;
        #0.5 clock = 1'b0;
        #0.5;
    end
    
    wire bitstream;

    reg [3:0] clk_divider = 0;
    always_ff @(posedge clock) begin
        if (!reset) begin
            clk_divider <= 0;
            modulator_clock <= 0;
        end else begin
            if (clk_divider == 4) begin
                clk_divider <= 0;
                modulator_clock <= ~modulator_clock;
            end else begin
                clk_divider <= clk_divider + 1;
            end
        end
    end

    axi_stream data_in();

    sigma_delta_modulator #(
        .INPUT_WIDTH(16)
    )UUT(
        .clock(clock),
        .reset(reset),
        .modulator_clock(modulator_clock),
        .data_out(bitstream),
        .data_in(data_in)
    );

    // 1kHz Sine Generation for Testbench
    real amplitude   = 32000;      
    real sine = 0;
    real phase = 0;

    initial begin
        data_in.initialize();
        reset <=1'h1;
        #10 reset <=1'h0;
        //TESTS
        #20.5 reset <=1'h1;

        #50;
        
        forever begin
            data_in.write($rtoi(sine), 1);
            sine = amplitude * $sin(phase);
            // Explicitly increment phase by the constant step
            phase = phase + 0.001256637; 
            
            // Keep phase bounded to prevent eventual overflow (though not your current issue)
            if (phase >= 6.283185) phase = phase - 6.283185;

            #20;
        end
       
    end





endmodule