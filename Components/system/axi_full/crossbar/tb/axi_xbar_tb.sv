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
`include "interfaces.svh"
`include "axi_full_bfm.svh"

module axi_xbar_tb();
   

    reg clk, reset;

    axi_full_bfm bfm;

    AXI axi_out_1();
    AXI axi_out_2();

    AXI axi_in();

    axi_xbar #(
        .NM(1),
        .NS(2),
        .SLAVE_ADDR('{'h20000000,'h00000000}),
        .SLAVE_MASK('{'hF0000000,'hF0000000})
    ) UUT (
        .clock(clk),
        .reset(reset),
        .masters('{axi_in}),
        .slaves('{axi_out_1, axi_out_2})
    );

    always begin
        clk = 1'b1;
        #0.5 clk = 1'b0;
        #0.5;
    end
    
    initial begin  
        bfm = new(axi_in
        , 1);
        //Initial status
        reset <=1'h1;
        #10 reset <=1'h0;
        //TESTS
        #20.5 reset <=1'h1;

    end

    reg [31:0] write_address;
    reg [31:0] write_data;
    // test writes

    initial begin
        write_address = 0;
        write_data = 0;
        #30;
        forever begin
            #10;
            write_address = $urandom_range('h0fffffff, 'h00000000);
            write_data  = $urandom();
            bfm.write(write_address, write_data);
            #33;    
        end
    end 



endmodule