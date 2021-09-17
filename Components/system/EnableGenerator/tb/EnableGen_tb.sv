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

module EnableGen_tb();
    
    logic clk, rst;
    logic gen_en;
    wire en_out;

    parameter spi_mode_master = 0, spi_mode_slave = 1;

    //clock generation
    initial clk = 1; 
    always #0.5 clk = ~clk; 
    
    // reset generation
    initial begin
        rst <=1;
        #3 rst<=0;
        #5 rst <=1;
    end

    Simplebus s();


    enable_generator gen(
        .clock(clk),
        .reset(rst),
        .gen_enable_in(gen_en),
        .enable_out(en_out),
        .sb(s)
    );

    simplebus_BFM BFM;
    
    initial begin
        //INITIAL SETTINGS AND INSTANTIATIONS OF CLASSES
        BFM = new(s,1);
        gen_en = 0;

        #10 BFM.write(32'h0,31'h2);
        #5 gen_en =1;
        #20 BFM.write(32'h0,31'hC);
        #100 BFM.write(32'h0,31'h2);
    end
    
endmodule