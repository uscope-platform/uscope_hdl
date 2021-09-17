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
`include "SPI_BFM.svh"

module multiphase_sinusoid_generator_tb();
    
    reg [15:0] Ia;
    reg [15:0] Ib;
    reg [15:0] Ic;
    reg [15:0] Id;
    reg [15:0] Ie;
    reg [15:0] If; 

    localparam N_PHASES = 6;

    Simplebus s();
    axi_stream phase();
    defparam currents.DATA_WIDTH = 16;
    axi_stream currents();
    simplebus_BFM sb_BFM;
    axi_stream angle_out();
    reg clk, reset;

    reg timing_test;
    integer frequency;
    reg [15:0] phase_accumulator;
    reg [15:0] iq;

multiphase_reference_generator UUT(
    .clock(clk),
    .reset(reset),
    .phase(phase),
    .sync(1),
    .Id(100),
    .Iq(iq),
    .angle_out(angle_out),
    .reference_out(currents),
    .sb(s)
);
    //clock generation
    initial clk = 0; 
    always #0.5 clk = ~clk; 

    initial begin  
        phase.valid = 0;
        phase.data = 0;
        iq = 0;
        sb_BFM = new(s,1);
        phase_accumulator <= 0;
        frequency = 1;
        //Initial status
        reset <=1'h1;
        #10 reset <=1'h0;
        //TESTS
        #20.5 reset <=1'h1;
        #2000000 iq = 200;
        //#100000 frequency = 3;
    end

    initial begin
        #35.5
        forever begin
        phase.data = frequency*(phase_accumulator)%16'hffff;
        phase.valid = 1;
        phase_accumulator = phase_accumulator+1;
        #1 phase.valid = 0;
        #2;
        end
    end

    always @(posedge clk) begin
        if(currents.valid)begin
            case (currents.dest)
                0: Ia <= currents.data;
                1: Ib <= currents.data;
                2: Ic <= currents.data;
                3: Id <= currents.data;
                4: Ie <= currents.data;
                5: If <= currents.data;
            endcase
        end
    end

endmodule