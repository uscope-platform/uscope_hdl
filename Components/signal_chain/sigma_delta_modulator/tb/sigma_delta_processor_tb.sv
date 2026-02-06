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

    always begin
        modulator_clock = 1'b1;
        #5 modulator_clock = 1'b0;
        #5;
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
    initial begin
        data_in.initialize();
        reset <=1'h1;
        #10 reset <=1'h0;
        //TESTS
        #20.5 reset <=1'h1;

        #50;
        

        data_in.write(1254, 1);
       
    end





endmodule