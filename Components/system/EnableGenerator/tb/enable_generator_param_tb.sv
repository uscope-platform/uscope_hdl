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
`include "axi_lite_BFM.svh"
`include "interfaces.svh"

module enable_generator_param_tb();
    
    logic clk, rst;
    logic gen_en;
    wire [4:0] en_out;

    //clock generation
    initial clk = 1; 
    always #0.5 clk = ~clk; 
    
    // reset generation
    initial begin
        rst <=1;
        #3 rst<=0;
        #5 rst <=1;
    end

    axi_lite axil();

    enable_generator_param #(
        .N_ENABLES(5)
    )gen(
        .clock(clk),
        .reset(rst),
        .gen_enable_in(gen_en),
        .enable_out(en_out),
        .axil(axil)
    );

    localparam control_addr = 0;
    localparam period_addr = 4;
    localparam treshold_0_addr = 8;
    localparam treshold_1_addr = 12;
    localparam treshold_2_addr = 16;
    localparam treshold_3_addr = 20;
    localparam treshold_4_addr = 24;
    
    axi_lite_BFM axi_bfm;
    reg [31:0] period;

    initial begin
        //INITIAL SETTINGS AND INSTANTIATIONS OF CLASSES
        axi_bfm = new(axil,1);
        gen_en = 0;
        #10 axi_bfm.write(period_addr, 16);
        #3 axi_bfm.write(treshold_0_addr,32'h4);
        #3 axi_bfm.write(treshold_1_addr,32'h5);
        #3 axi_bfm.write(treshold_2_addr,32'h6);
        #3 axi_bfm.write(treshold_4_addr,32'h9);
        #5 gen_en =1;
        #2000 
        axi_bfm.write(period_addr, 32);
        #100 axi_bfm.write(treshold_0_addr,32'h10);

    end
    

endmodule