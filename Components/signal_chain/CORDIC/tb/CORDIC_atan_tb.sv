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

module CORDIC_atan_tb();

    reg  clock, reset;

    axi_stream #(.DATA_WIDTH(16)) sin();
    axi_stream #(.DATA_WIDTH(16)) cos();
    axi_stream #(.DATA_WIDTH(16)) angle();

    event config_done;

    CORDIC_atan#(
        .RESOLUTION(16)
    )UUT(
        .clock(clock),
        .reset(reset),
        .x(cos), 
        .y(sin),
        .out(angle)
    );

    always begin
        clock = 1'b1;
        #0.5 clock = 1'b0;
        #0.5;
    end


    initial begin

        reset <=1'h1;
        #10 reset <=1'h0;
        //TESTS
        #21 reset <=1'h1;
        #50;
        ->config_done;
    end

    // Configuration & Constants
    real PI = 3.14159265358979323846;
    int NUM_SAMPLES = 360;  // 1-degree steps full rotation
    
    // Scale factor for signed 16-bit Q1.15 fixed-point (max positive value ~32767)
    real AMPLITUDE = 32767.0; 

    real theta;
    shortint cos_val, sin_val;

    initial begin
        // Initialize interface signals
        sin.initialize();
        cos.initialize();

        @(config_done);

        // Drive sine and cosine wave pairs across a full circle (0 to 2*PI)
        for (int i = 0; i < NUM_SAMPLES; i++) begin
            theta   = (2.0 * PI * i) / NUM_SAMPLES;
            
            // Generate Q1.15 fixed-point values
            cos_val = $rtoi(AMPLITUDE * $cos(theta));
            sin_val = $rtoi(AMPLITUDE * $sin(theta));

            // Concurrent push to both interfaces
            fork
                cos.write(cos_val);
                sin.write(sin_val);
            join

            // Optional delay between successive samples
            repeat(32) @(posedge clock);
        end

        ->config_done;
        #100 $finish;
    end

    // Slave driver for the output interface (AXI Stream handshake receiver)
    initial begin
        angle.ready = 1'b1; // Continuously accept outputs from CORDIC
    end

endmodule