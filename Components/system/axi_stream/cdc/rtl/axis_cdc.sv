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

`timescale 10ns / 1ns
`include "interfaces.svh"

module axis_cdc #(parameter CDC_STYLE = "FF", N_STAGES = 3, DATA_WIDTH = 32, USER_WIDTH = 32, DEST_WIDTH = 32)(
    input wire reset,
    input wire clock_in,
    input wire clock_out,
    axi_stream.slave in,
    axi_stream.master out
    );

    reg [DATA_WIDTH-1:0] data_meta[N_STAGES-1:0];
    reg [USER_WIDTH-1:0] user_meta[N_STAGES-1:0];
    reg [DEST_WIDTH-1:0] dest_meta[N_STAGES-1:0];
    reg [3:0] valid_meta, ready_meta;

    assign out.data = data_meta[N_STAGES-1];
    assign out.user = user_meta[N_STAGES-1];
    assign out.dest = dest_meta[N_STAGES-1];
    assign out.valid = valid_meta[N_STAGES-1];
    generate
    if(CDC_STYLE == "FF")begin
        always @(posedge clock_out) begin
            for(integer i = 0; i< N_STAGES; i = i+1)begin
                data_meta[i+1] = data_meta[i];
            end
            data_meta[0] <= in.data;

            for(integer i = 0; i< N_STAGES; i = i+1)begin
                user_meta[i+1] = user_meta[i];
            end
            user_meta[0] <= in.user;

            for(integer i = 0; i< N_STAGES; i = i+1)begin
                dest_meta[i+1] = dest_meta[i];
            end
            dest_meta[0] <= in.dest;

            for(integer i = 0; i< N_STAGES; i = i+1)begin
                valid_meta[i+1] = valid_meta[i];
            end
            valid_meta[0] <= in.valid;

            in.ready <= out.ready;
        end

    end else if(CDC_STYLE == "HANDSHAKE")begin
        
        reg cdc_ready_b, cdc_valid_b;
        always@(posedge clock_in)begin
            if(~reset)begin{ in.ready, ready_meta } <= { ready_meta, out.ready};
                cdc_valid_b <= 0;
                in.ready <= 1;
            end else begin
                if(in.valid)begin
                    cdc_valid_b <= 1;
                    in.ready <= 0;
                end
                if(cdc_ready_b) begin
                    cdc_valid_b <= 0;
                end
                if(~cdc_ready_b & ~in.valid & ~cdc_valid_b )begin
                    in.ready <= 1;
                end
            end
        end



        defparam op_cdc_data.DEST_EXT_HSK = 0;
        defparam op_cdc_data.DEST_SYNC_FF = 2;
        defparam op_cdc_data.INIT_SYNC_FF = 1;
        defparam op_cdc_data.SIM_ASSERT_CHK = 1;
        defparam op_cdc_data.SRC_SYNC_FF = 2;
        defparam op_cdc_data.WIDTH = 32;

        xpm_cdc_handshake op_cdc_data (
            .dest_out(out.data),
            .dest_req(out.valid),
            .src_rcv(cdc_ready_b),
            .dest_clk(clock_out),
            .src_clk(clock_in),
            .src_in(in.data),
            .src_send(cdc_valid_b)
        );
    
    
        defparam op_cdc_dest.DEST_EXT_HSK = 0;
        defparam op_cdc_dest.DEST_SYNC_FF = 2;
        defparam op_cdc_dest.INIT_SYNC_FF = 1;
        defparam op_cdc_dest.SIM_ASSERT_CHK = 1;
        defparam op_cdc_dest.SRC_SYNC_FF = 2;
        defparam op_cdc_dest.WIDTH = 32;

        xpm_cdc_handshake op_cdc_dest (
            .dest_out(out.dest),
            .dest_clk(clock_out),
            .src_clk(clock_in),
            .src_in(in.dest),
            .src_send(cdc_valid_b)
        );

    end
    endgenerate

endmodule
