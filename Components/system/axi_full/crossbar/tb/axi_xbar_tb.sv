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

    AXI #(.ADDR_WIDTH(32)) axi_out_1();
    AXI #(.ADDR_WIDTH(32)) axi_out_2();

    AXI #(.ADDR_WIDTH(32)) axi_in();
    axi_full_bfm #(.ADDR_WIDTH(32)) bfm_in;

    axi_xbar #(
        .NM(1),
        .NS(2),
        .SLAVE_ADDR('{'h20000000,'h00000000}),
        .SLAVE_MASK('{'hF0000000,'hF0000000})
    ) UUT (
        .clock(clk),
        .reset(reset),
        .slaves('{axi_in}),
        .masters('{axi_out_1, axi_out_2})
    );


    reg [31:0] write_addr_1;
    reg [31:0] write_data_1;
    reg [31:0] read_addr_1;

    reg [31:0] write_addr_2;
    reg [31:0] write_data_2;
    reg [31:0] read_addr_2;

    axi_slave_sink slave_a(
        .clock(clk),
        .reset(reset),
        .axi(axi_out_1),
        .write_addr(write_addr_1),
        .write_data(write_data_1),
        .read_addr(read_addr_1)
    );

    axi_slave_sink slave_b(
        .clock(clk),
        .reset(reset),
        .axi(axi_out_2),
        .write_addr(write_addr_2),
        .write_data(write_data_2),
        .read_addr(read_addr_2)
    );

    always begin
        clk = 1'b1;
        #0.5 clk = 1'b0;
        #0.5;
    end
    
    initial begin  
        bfm_in = new(axi_in, 1);
        //Initial status
        reset <=1'h1;
        #10 reset <=1'h0;
        //TESTS
        #20.5 reset <=1'h1;

    end

    reg slave_select = 0;
    reg [31:0] write_addr_var;
    reg [31:0] write_address;
    reg [31:0] write_data;
    // test writes
    event write_complete;

    initial begin
        write_address = 0;
        write_data = 0;
        #90;
        forever begin
            #10;
            slave_select = $urandom() % 2;
            write_addr_var = $urandom() & 'h0FFFFFFF;
            write_address = slave_select ? write_addr_var | 'h20000000 : write_addr_var;
            write_data  = $urandom();
            bfm_in.write(write_address, write_data);
            #5
            ->write_complete;
            #33;    
        end
    end 


    always begin
        @(write_complete);
        if(slave_select) begin
            assert (write_data_1 == write_data) 
            else   $display("Error on slave 1 data");
            assert (write_addr_1 == write_address) 
            else   $display("Error on slave 1 address");
        end else begin
            assert (write_data_2 == write_data) 
            else   $display("Error on slave 2 data");
            assert (write_addr_2 == write_address) 
            else   $display("Error on slave 2 address");
        end
    end
endmodule