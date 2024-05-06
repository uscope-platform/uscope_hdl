

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
`include "interfaces.svh"


module multichannel_axis_sync_repeater #(
    parameter DATA_WIDTH= 32, 
    DEST_WIDTH = 8,
    USER_WIDTH = 8,
    WAIT_INITIALIZATION = 1,
    N_CHANNELS = 8
)(
    input wire        clock,
    input wire        reset,
    input wire        sync,
    axi_stream.slave in,
    axi_stream.master out
);

    assign in.ready = out.ready;
    

    axi_stream selected_streams[N_CHANNELS]();
    axi_stream synced_streams[N_CHANNELS]();
    genvar i;

    generate
        for (i = 0; i<N_CHANNELS; i++ ) begin
                
            axi_stream_extractor #(
                .DATA_WIDTH(DATA_WIDTH),
                .DEST_WIDTH(DEST_WIDTH),
                .REGISTERED(0)
            )extractor (
                .clock(clock),
                .selector(i),
                .out_dest(i),
                .stream_in(in),
                .stream_out(selected_streams[i])
            );


            axis_sync_repeater #(
                .DATA_WIDTH(DATA_WIDTH),
                .DEST_WIDTH(DEST_WIDTH),
                .USER_WIDTH(USER_WIDTH),
                .HOLD_VALID(1),
                .WAIT_INITIALIZATION(WAIT_INITIALIZATION),
                .N_CHANNELS(N_CHANNELS)
            )inner_repeater(
                .clock(clock),
                .reset(reset),
                .sync(sync),
                .in(selected_streams[i]),
                .out(synced_streams[i])
            );

        end
    endgenerate

    axis_multichannel_combiner #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEST_WIDTH(DEST_WIDTH),
        .USER_WIDTH(USER_WIDTH),
        .N_CHANNELS(N_CHANNELS)
    )out_combiner(
        .clock(clock),
        .reset(reset),
        .data_in(synced_streams),
        .data_out(out)
    );



endmodule