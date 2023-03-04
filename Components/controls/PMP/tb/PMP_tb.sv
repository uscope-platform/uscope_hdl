

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
`include "axis_BFM.svh"
`include "interfaces.svh"

module PMP_tb();
    reg clk, reset;

    axi_lite ctrl_axi();
    axi_lite axi_pwm_dab();


    axis_BFM write_BFM;
    axis_BFM read_req_BFM;
    axis_BFM read_resp_BFM;

    axi_stream read_req();
    axi_stream read_resp();
    axi_stream write();

    axis_to_axil WRITER(
        .clock(clk),
        .reset(reset), 
        .axis_write(write),
        .axis_read_request(read_req),
        .axis_read_response(read_resp),
        .axi_out(ctrl_axi)
    );

    pre_modulation_processor #(
        .CONVERTER_SELECTION("DYNAMIC"),
        .PWM_BASE_ADDR(0)
    ) UUT (
        .clock(clk),
        .reset(reset),
        .axi_in(ctrl_axi),
        .axi_out(axi_pwm_dab)
    );


    PwmGenerator #(
       .BASE_ADDRESS(0)
    ) dab_gen_checker(
        .clock(clk),
        .reset(reset),
        .ext_timebase(0),
        .fault(0),
        .axi_in(axi_pwm_dab)
    );


    //clock generation
    initial clk = 0; 
    always #0.5 clk = ~clk; 


    initial begin
        write_BFM = new(write,1);
        read_req_BFM = new(read_req, 1);
        read_resp_BFM = new(read_resp, 1);
        //Initial status
        reset <=1'h1;
        #1 reset <=1'h0;
        //TESTS
        #5.5 reset <=1'h1;

        #1 write_BFM.write_dest(1000, 'h4);
        #1 write_BFM.write_dest(500, 'h8);
        #1 write_BFM.write_dest(200, 'hc);
        #1 write_BFM.write_dest(40, 'h10);
        #30;
        #1 write_BFM.write_dest('h30, 'h0);
    end

endmodule