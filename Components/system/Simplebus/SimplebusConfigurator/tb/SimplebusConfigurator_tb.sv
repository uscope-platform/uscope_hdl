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

module SimplebusConfigurator_tb();
    
    logic clk, start;
    Simplebus s();

    reg [31:0] config_data [9:0];
    reg [31:0] config_address [9:0];

    SimplebusConfigurator UUT (
        .clock(clk),
        .start(start),
        .config_address(config_address),
        .config_data(config_data),
        .sb(s)
    );



    //clock generation
    initial clk = 1; 
    always #0.5 clk = ~clk; 
    



    simplebus_BFM BFM;
    
    initial begin
        //INITIAL SETTINGS AND INSTANTIATIONS OF CLASSES
        BFM = new(s,1);
        start <= 0;
        config_address <= {1,2,3,4,5,6,7,8,9,10};
        config_data <= {1,2,3,4,5,6,7,8,9,10};
        //TEST MASTER MODE
        s.sb_ready <= 1;
        #10 start <= 1;
        #1 start <= 0;
    
    
    end
    
endmodule