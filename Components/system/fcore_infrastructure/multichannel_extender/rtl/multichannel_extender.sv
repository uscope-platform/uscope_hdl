

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


module multichannel_extender #(
    parameter DATA_WIDTH= 32, 
    DEST_WIDTH = 32,
    USER_WIDTH = 32,
    N_CHANNELS = 2,
    N_REPEAT_VALUES = 1
)(
    input wire        clock,
    input wire        reset,
    input wire [31:0] repeat_dest [N_REPEAT_VALUES-1:0],
    axi_stream.slave  in,
    axi_stream.master out
);

    axi_stream registered_stream();
    
    axis_skid_buffer #(
        .REGISTER_OUTPUT(1),
        .LATCHING(1),
        .DATA_WIDTH(32)
    ) buffer (
        .clock(clock),
        .reset(reset),
        .axis_in(in),
        .axis_out(registered_stream)
    );

    initial begin
        out.data <= 0;
        out.dest <= 0;
        out.user <= 0;
        out.tlast <= 0;
        out.valid <= 0;
    end

    enum logic {
       idle = 0,
       extending = 1
    } extender_state = idle;

    assign registered_stream.ready = out.ready;

    reg [$clog2(N_CHANNELS)-1:0] extension_ctr = 0;
    reg [15:0] dest_word = 0;

    reg [DATA_WIDTH-1:0] latched_data;
    reg [DATA_WIDTH-1:0] latched_user;

    always_ff@(posedge clock)begin
        case (extender_state)
            idle: begin
                for(integer i =0; i<N_REPEAT_VALUES; i++)begin
                    if(in.valid && in.dest[15:0] == repeat_dest[i]) begin
                        latched_data <= in.data;
                        latched_user <= in.user;
                        extender_state <= extending;
                        dest_word <= repeat_dest[i];
                    end
                end
            end
            extending: begin
                if(extension_ctr == N_CHANNELS-1)begin
                    extension_ctr <= 0;
                    extender_state <= idle;
                end else begin
                    extension_ctr <= extension_ctr+1;
                end
            end
        endcase
    end

    always_comb begin
           case (extender_state)
            idle: begin
                out.valid <= 0;
                out.tlast <= 0;
                out.data <= 0;
                out.user <= 0;
                out.dest <= 0;
            end
            extending: begin
                out.data <= latched_data;
                out.user <= latched_user;
                out.valid <= 1;
                out.dest <= {extension_ctr, dest_word};
                if(extension_ctr == N_CHANNELS-1)begin
                    out.tlast <= 1;
                end else begin
                    out.tlast <= 0;
                end
            end
            endcase
    end

endmodule
