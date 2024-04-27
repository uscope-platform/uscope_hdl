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

    event config_done;
    
    axi_lite cfg_axi();
    axi_lite_BFM axil_bfm;


    axi_stream #(
        .DATA_WIDTH(32)
    ) filter_out();


    reg sd_in = 0;
    wire sd_clk;
    reg out_clk;

    
    sigma_delta_processor #(
        .DECIMATION_RATIO(64)
    ) UUT(
        .clock(clk),
        .reset(reset),
        .data_in({sd_in, ~sd_in}),
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
        $readmemh("/home/fils/git/uscope_hdl/public/Components/signal_chain/SigmaDeltaProcessor/tb/data.csv", stimulus);
        axil_bfm = new(cfg_axi, 1);
        filter_out.ready <= 1;
        reset <=1'h1;
        #10 reset <=1'h0;
        //TESTS
        #20.5 reset <=1'h1;

        #50;
        
        axil_bfm.write(0, 101);

        ->config_done;
    end



    initial begin
        @(config_done);

    end

    reg [31:0] output_1;
    reg [31:0] output_2;

    always_ff@(posedge clk)begin
        if(filter_out.valid)begin
            if(filter_out.dest == 0)begin
                output_1 <= filter_out.data;
            end else if(filter_out.dest ==1) begin
                output_2 <= filter_out.data;
            end
        end
    end

    reg [15:0] stimulus_ctr = 0;

    always_ff@(posedge sd_clk)begin
        if(stimulus_ctr<44000)begin
            stimulus_ctr <= stimulus_ctr +1;
        end else begin
            stimulus_ctr <= 0;
        end
        sd_in <= stimulus[stimulus_ctr];
    end

endmodule