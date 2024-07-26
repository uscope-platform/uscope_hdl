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
`include "interfaces.svh"


module sigma_delta_processor_tb();

    reg  clk, reset;

    reg stimulus [44000:0];

    parameter  N_CHANNELS = 4;

    event config_done;
    
    axi_lite cfg_axi();
    axi_lite_BFM axil_bfm;


    axi_stream #(
        .DATA_WIDTH(32)
    ) filter_out();


    wire sd_clk;

    wire [N_CHANNELS-1:0] sd_in;

    localparam OUTPUT_DESTINATION_BASE = 3;

    sigma_delta_processor #(
        .MAIN_DECIMATION_RATIO(512),
        .N_CHANNELS(N_CHANNELS),
        .OUTPUT_DESTINATION_BASE(OUTPUT_DESTINATION_BASE)
    ) UUT(
        .clock(clk),
        .reset(reset),
        .enable(1),
        .data_in(sd_in),
        .clock_out(sd_clk),
        .sync(1),
        .axi_in(cfg_axi),
        .data_out(filter_out)
    );
 
    always begin
        clk = 1'b1;
        #0.5 clk = 1'b0;
        #0.5;
    end

    initial begin
        $readmemh("/home/filssavi/git/uplatform-hdl/public/Components/signal_chain/SigmaDeltaProcessor/tb/data.csv", stimulus);
        axil_bfm = new(cfg_axi, 1);
        filter_out.ready <= 1;
        reset <=1'h1;
        #10 reset <=1'h0;
        //TESTS
        #20.5 reset <=1'h1;

        #50;
        
        axil_bfm.write('h0, -15000);
        axil_bfm.write('h4, -20000);
        axil_bfm.write('h8, -40000);
        axil_bfm.write('hC, -40000);


        axil_bfm.write('h10, 15000);
        axil_bfm.write('h14, 20000);
        axil_bfm.write('h18, 40000);
        axil_bfm.write('h1C, 40000);


        axil_bfm.write('h20, 0);
        axil_bfm.write('h24, -3000);
        axil_bfm.write('h28, 3000);
        axil_bfm.write('h2C, 0);

        ->config_done;
    end



    reg [30:0] outputs [N_CHANNELS-1:0];


    reg [15:0] stimulus_ctr [N_CHANNELS-1:0];
    genvar i;

    initial begin
        for( integer j = 0; j< N_CHANNELS; j++)begin
            stimulus_ctr[j] = 40000/N_CHANNELS*j*0.2;
        end
    end


    reg [3:0] base_bitstream = 0;

    assign sd_in[0] = base_bitstream[0];
    assign sd_in[1] = base_bitstream[1];
    assign sd_in[2] = base_bitstream[2];
    assign sd_in[3] = base_bitstream[3];
 
    for( i = 0; i< N_CHANNELS; i++)begin

        always_ff@(posedge clk)begin
            if(filter_out.valid)begin
                if(filter_out.dest == i+OUTPUT_DESTINATION_BASE)begin
                    outputs[filter_out.dest-OUTPUT_DESTINATION_BASE] <= filter_out.data;
                end
            end
        end


        always_ff@(posedge sd_clk)begin
            if(stimulus_ctr[i]<40000)begin
                stimulus_ctr[i] <= stimulus_ctr[i] +1;
            end else begin
                stimulus_ctr[i] <= 0;
            end
            base_bitstream[i] <= stimulus[stimulus_ctr[i]];
        end
    end


endmodule