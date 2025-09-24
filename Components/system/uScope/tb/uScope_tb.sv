

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

module uScope_tb();
    reg  clock, sampling_clock, reset;

    axi_lite axil();

    axi_lite_BFM axil_bfm;

    axi_stream data_in[6]();

    AXI scope_out();

    wire dma_done;

    localparam BASE_ADDRESS = 'h43C00000;

    axi_full_slave_sink #(
        .BUFFER_SIZE(6144),
        .BASE_ADDRESS('h3f000000),
        .BVALID_LATENCY(20)
    )sink(
        .clock(clock),
        .reset(reset),
        .axi_in(scope_out)
    );

    uScope_dma #(
        .DATA_WIDTH(32),
        .DEST_WIDTH(16),
        .N_STREAMS(6),
        .OUTPUT_AXI_WIDTH(64),
        .BURST_SIZE(8),
        .CHANNEL_SAMPLES(1024)
    ) UUT (
        .clock(clock),
        .reset(reset),
        .dma_done(dma_done),
        .disable_dma(0),
        .axi_in(axil),
        .out(scope_out),
        .stream_in(data_in)
    );


    //clock generation
    initial clock = 0;
    always #0.5 clock = ~clock;

    initial begin
        sampling_clock <= 0;
        #0.5;
        forever begin
           #10 sampling_clock = 1;
           #1 sampling_clock = 0;
        end
    end

    event cfg_done;

    initial begin
        axil_bfm = new(axil, 1);
        //Initial status
        reset <=1'h1;
        #1 reset <=1'h0;
        //TESTS
        #5.5 reset <=1'h1;


        #8;

        #10 axil_bfm.write(BASE_ADDRESS+reg_maps::uscope_regs.buffer_addr_low, 32'h3f000000);
        #10 axil_bfm.write(BASE_ADDRESS+reg_maps::uscope_regs.trigger_level, 'h43c80000);
        #10 axil_bfm.write(BASE_ADDRESS+reg_maps::uscope_regs.channel_selector, 0);
        #10 axil_bfm.write(BASE_ADDRESS+reg_maps::uscope_regs.acquisition_mode, 0);
        #10 axil_bfm.write(BASE_ADDRESS+reg_maps::uscope_regs.trigger_point, 32'h200);
        #7000;
        //#10 axil_bfm.write(BASE_ADDRESS+reg_maps::uscope_regs.acquisition_mode, 2);
        ->cfg_done;
    end

    reg [9:0] data_ctr = 0;

    always_ff @(posedge clock) begin
        if(sampling_clock)begin
            data_ctr <= data_ctr+1;
            if(data_in[0].ready)begin
                data_in[0].data <= data_ctr;
                data_in[0].user <= get_axis_metadata(16,0, 0);
                data_in[0].dest <= 0;
                data_in[0].valid <= 1;
            end

            if(data_in[1].ready)begin
                data_in[1].data <= data_ctr + 1000;
                data_in[1].user <= get_axis_metadata(16,0, 0);
                data_in[1].dest <= 1;
                data_in[1].valid <= 1;
            end

            if(data_in[2].ready)begin
                data_in[2].data <=  data_ctr + 2000;
                data_in[2].user <=  get_axis_metadata(16,0, 0);
                data_in[2].dest <= 2;
                data_in[2].valid <= 1;
            end

            if(data_in[3].ready)begin
                data_in[3].data <=  data_ctr + 3000;
                data_in[3].user <=  get_axis_metadata(16,0, 0);
                data_in[3].dest <= 3;
                data_in[3].valid <= 1;
            end

            if(data_in[4].ready)begin
                data_in[4].data <=  data_ctr + 4000;
                data_in[4].user <= get_axis_metadata(16,0, 0);
                data_in[4].dest <= 4;
                data_in[4].valid <= 1;
            end

            if(data_in[5].ready)begin
                data_in[5].data <= data_ctr + 5000;
                data_in[5].user <= get_axis_metadata(16,0, 0);
                data_in[5].dest <= 5;
                data_in[5].valid <= 1;
            end
        end else begin
            data_in[0].valid <= 0;
            data_in[1].valid <= 0;
            data_in[2].valid <= 0;
            data_in[3].valid <= 0;
            data_in[4].valid <= 0;
            data_in[5].valid <= 0;
        end

    end



endmodule
