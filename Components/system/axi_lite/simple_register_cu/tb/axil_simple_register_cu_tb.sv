// Copyright (C) : 3/16/2018, 11:06:33 AM Filippo Savi - All Rights Reserved

// This file is part of sicdrive-hdl.

// sicdrive-hdl is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as 
// published by the Free Software Foundation, either version 3 of the
// License.

// sicdrive-hdl is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU Lesser General Public License
// along with sicdrive-hdl.  If not, see <https://www.gnu.org/licenses/>.
`timescale 10 ns / 1 ns
`include "interfaces.svh"
`include "axi_lite_BFM.svh"

module axil_simple_register_cu_tb();
   
    axi_lite test_axi();

    reg clk, reset;
    reg sclk = 0;

  
    axi_lite_BFM axil_bfm;
 
    logic [31:0] input_registers [2:0] = {0,0,0};
    logic [31:0] output_registers [2:0];
    axil_simple_register_cu #(
        .N_READ_REGISTERS(3),
        .N_WRITE_REGISTERS(3)
    ) UUT (
        .clock(clk),
        .reset(reset),
        .input_registers(input_registers),
        .output_registers(output_registers),
        .axil(test_axi)
    );
    
    always begin
        clk = 1'b1;
        #0.5 clk = 1'b0;
        #0.5;
    end
    
    reg [31:0] write_shadow_register [2:0] = {0,0,0};
    reg [31:0] write_address;
    reg [31:0] write_data;

    initial begin  
        axil_bfm = new(test_axi,1);
        //Initial status
        reset <=1'h1;
        #10 reset <=1'h0;
        //TESTS
        #20.5 reset <=1'h1;

    end

    // test writes
    initial begin
        write_address = 0;
        write_data = 0;
        #30;
        forever begin
            #10;
            write_address = $urandom()%3;
            write_data = $urandom();
            write_shadow_register[write_address] = write_data;
            axil_bfm.write(write_address, write_data);
            #3;
            if(write_shadow_register != output_registers) begin
                $error("output registers != write shadow registers");
            end
            #30;    
        end
    end 

    reg [31:0] read_shadow_register [2:0] = {0,0,0};
    reg [31:0] read_address;
    reg [31:0] read_data;

    reg [31:0] readback;
    reg read_func = 0;
     // test reads
    initial begin
        read_address = 0;
        read_data = 0;
        read_func <= 0;
        #30;
        #5;
        forever begin
            #10
            read_address = $urandom()%3;
            read_data = $urandom();
            input_registers[read_address] = read_data;
            #3;
            read_func = 1;
            axil_bfm.read(read_address, readback);
            read_func = 0;
            read_shadow_register[read_address] = readback;
            if(read_shadow_register != input_registers) begin
                $error("input registers != read shadow registers");
            end
            #20;   
        end
    end 

endmodule