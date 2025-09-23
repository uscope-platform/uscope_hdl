

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
`include "axis_BFM.svh"


import reg_maps::*;

module trigger_engine_tb();
    reg  clock, reset;

    axi_lite axil();

    axi_lite_BFM axil_bfm;

    axi_stream data_in[2]();

    wire trigger;

    trigger_engine #(
        .N_CHANNELS(2),
        .MEMORY_DEPTH(1023)
    ) UUT(
        .clock(clock),
        .reset(reset),
        .data_in(data_in),
        .axi_in(axil),
        .trigger_out(trigger)
    );

    //clock generation
    initial clock = 0;
    always #0.5 clock = ~clock;


    event cfg_done;

    initial begin
        axil_bfm = new(axil, 1);
        //Initial status
        reset <=1'h1;
        #1 reset <=1'h0;
        //TESTS
        #5.5 reset <=1'h1;


        #8;

        #5 axil_bfm.write(reg_maps::uscope_regs.buffer_addr_low, 32'h3f000000);
        #5 axil_bfm.write(reg_maps::uscope_regs.trigger_level, $shortrealtobits($itor(1300)));
        #5 axil_bfm.write(reg_maps::uscope_regs.channel_selector, 0);
        #5 axil_bfm.write(reg_maps::uscope_regs.acquisition_mode, 0);
        #5 axil_bfm.write(reg_maps::uscope_regs.trigger_point, 32'h600);
        ->cfg_done;
    end

    int test_stage = 0;
    int data_counter = 0;
    initial begin
        data_in[0].data <= 0;
        data_in[0].dest <= 0;
        data_in[0].user <= 0;
        data_in[0].valid <= 0;
        data_in[0].tlast <= 0;
        data_in[1].data <= 0;
        data_in[1].dest <= 0;
        data_in[1].user <= 0;
        data_in[1].valid <= 0;
        data_in[1].tlast <= 0;
        @(cfg_done);
        forever begin
            @(posedge clock)

            if(test_stage==0)begin
                data_in[0].data <= $shortrealtobits($itor(data_counter));
                data_in[0].user <= get_axis_metadata(32, 1, 1);
            end
            if(test_stage ==1)begin
                data_in[0].data <= data_counter;
                data_in[0].user <= get_axis_metadata(24, 0, 0);
            end
            if(trigger)begin
                data_counter = 0;
                test_stage++;
                data_in[0].valid = 0;
                #50;
            end

            data_in[0].dest <= 1;
            data_in[0].valid <= 1;
            data_in[0].tlast <= 0;
            data_counter++;
        end
    end



endmodule