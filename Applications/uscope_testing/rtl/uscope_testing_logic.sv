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


`timescale 10ns / 1ns
`include "interfaces.svh"

module uscope_testing_logic (
    input wire clock,
    input wire reset,
    output wire dma_done,
    axi_lite.slave axi_in,
    AXI.master scope_out
);


    axi_lite #(.INTERFACE_NAME("TIMEBASE")) timebase_axi();
    axi_lite #(.INTERFACE_NAME("SCOPE")) scope_axi();
    axi_lite #(.INTERFACE_NAME("GPIO")) gpio_axi();
    

    localparam timebase_addr = 'h43c00000;
    localparam scope_addr = 'h43c10000;
    localparam gpio_addr = 'h43c20000;

    localparam [31:0] AXI_ADDRESSES [2:0] = '{
        gpio_addr,
        timebase_addr,
        scope_addr
    };

    axil_crossbar_interface #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(32),
        .NM(1),
        .NS(3),
        .SLAVE_ADDR(AXI_ADDRESSES),
        .SLAVE_MASK('{3{32'hf0000}})
    ) axi_xbar (
        .clock(clock),
        .reset(reset),
        .slaves('{axi_in}),
        .masters('{gpio_axi, timebase_axi, scope_axi})
    );

    wire enable, sampling_sync;
    gpio #(
        .INPUT_WIDTH(16),
        .OUTPUT_WIDTH(16)
    ) io_control(
        .clock(clock),
        .reset(reset),
        .gpio_i(0),
        .gpio_o({trigger, enable}),
        .axil(gpio_axi)
    );

    enable_generator #(
        .COUNTER_WIDTH(32)
    ) dab_timebase (
        .clock(clock),
        .reset(reset),
        .gen_enable_in(enable),
        .enable_out(sampling_sync),
        .axil(timebase_axi)
    );

    wire trigger;

    axi_stream scope_in();

    reg [3:0] channel_ctr = 0;
    reg [10:0] data_ctr = 0;

    always_ff @(posedge clock) begin
        scope_in.user <= get_axis_metadata(16, 0, 0);
        if(sampling_sync)begin
            scope_in.data <= data_ctr + 100*channel_ctr;
            scope_in.dest <= channel_ctr;
            
            channel_ctr <= channel_ctr + 1;
            if(channel_ctr == 5) begin
                channel_ctr <= 0;
                data_ctr <= data_ctr + 1;
            end
            scope_in.valid <= 1;
        end else begin
            scope_in.user <= 0;
            scope_in.valid <= 0;
            scope_in.tlast <= 0;
        end
    end


    uScope_stream_dma #(
        .N_TRIGGERS(0),
        .SCOPE_BASE_ADDRESS(scope_addr),
        .OUTPUT_AXI_WIDTH(64),
        .CHANNEL_SAMPLES(1024),
        .BURST_SIZE(8)
    ) scope(
        .clock(clock),
        .reset(reset),
        .sampling_clock(scope_in.valid),
        .dma_done(dma_done),
        .axi_in(scope_axi),
        .scope_out(scope_out),
        .data_in(scope_in)
    );
    

endmodule