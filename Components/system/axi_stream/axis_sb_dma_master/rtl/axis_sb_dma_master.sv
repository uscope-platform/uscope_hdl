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

module axis_sb_dma_master #(
    parameter BASE_ADDRESS = 'h43c00000,
    CHANNEL_OFFSET = 'h0,
    DESTINATION_OFFSET = 'h0,
    CHANNEL_NUMBER = 3,
    LAST_DESTINATION = 1,
    FIFO_DEPTH = 16,
    SB_DELAY = 3,
    parameter [7:0] CHANNEL_SEQUENCE [CHANNEL_NUMBER-1:0]= {3,2,1}
)(
    input wire clock,
    input wire reset,
    output reg done,
    axi_stream.slave stream,
    Simplebus.master sb
);

    enum reg [1:0] { 
        idle = 0,
        wait_xbar = 1,
        emit_done = 2,
        multichannel_op = 3
     } state;


    reg [$clog2(FIFO_DEPTH)-1:0] fifo_write_head;
    reg [$clog2(FIFO_DEPTH)-1:0] fifo_read_head;
    reg [31:0] data_fifo [FIFO_DEPTH-1:0];
    reg [7:0] dest_fifo [FIFO_DEPTH-1:0];
    reg [7:0] user_fifo [FIFO_DEPTH-1:0];

    always_ff @(posedge clock) begin
        if(!reset)begin
            fifo_write_head <= 0;
        end else begin
            if(stream.valid)begin
                data_fifo[fifo_write_head] <= stream.data;
                dest_fifo[fifo_write_head] <= stream.dest;
                user_fifo[fifo_write_head] <= stream.user;
                fifo_write_head <= fifo_write_head + 1;
            end
        end
    end

    reg [$clog2(SB_DELAY)-1:0] wait_counter;
    reg [$clog2(CHANNEL_NUMBER)-1:0] sc_channel_sequencer;
    reg [$clog2(CHANNEL_NUMBER)-1:0] mc_channel_sequencer;
    reg mc_operation;

    always_ff @(posedge clock) begin
        if(!reset)begin
            sc_channel_sequencer <= 0;
            mc_channel_sequencer <= 0;
            mc_operation <= 0;
            fifo_read_head <= 0;
            done <= 0;
            state <= idle;
        end else begin
            case (state)
                idle:begin
                    if((fifo_read_head != fifo_write_head) & sb.sb_ready) begin
                        if(user_fifo[fifo_read_head])begin
                            state <= multichannel_op;
                        end else begin
                            sb.sb_write_data <= data_fifo[fifo_read_head];
                            fifo_read_head <= fifo_read_head + 1;
                            sb.sb_write_strobe <= 1'b1;
                            state <= wait_xbar;
                            done <= 0;
                            sb.sb_address <= BASE_ADDRESS + (CHANNEL_SEQUENCE[sc_channel_sequencer]-1)*CHANNEL_OFFSET + DESTINATION_OFFSET*dest_fifo[fifo_read_head];
                            if(sc_channel_sequencer == CHANNEL_NUMBER-1) begin
                                sc_channel_sequencer <= 0;
                                if(dest_fifo[fifo_read_head]==LAST_DESTINATION)begin
                                    state <= emit_done;
                                end
                            end
                            else sc_channel_sequencer <= sc_channel_sequencer+1;    
                        end
                    end else begin
                        sb.sb_read_strobe <= 0;
                        wait_counter <= 0;                        
                        sb.sb_write_strobe <= 0;
                        sb.sb_write_data <= 0;
                        stream.ready <= 1;
                        sb.sb_address <= 0;
                        sb.sb_write_strobe <= 0;
                    end
                end 
                wait_xbar:begin
                    done <= 0;
                    sb.sb_write_strobe <= 0;
                    if(wait_counter==SB_DELAY-1)begin
                        wait_counter <= 0;
                        if(mc_operation) begin
                            state <= multichannel_op;
                        end else begin
                            state <= idle;    
                        end
                    end else begin
                        wait_counter <= wait_counter+1;
                    end

                end
                emit_done:begin
                    done <= 1;
                    state <= wait_xbar;
                    sb.sb_write_strobe <= 0;
                    wait_counter <= wait_counter+1;
                end
                multichannel_op:begin
                    mc_operation <= 1;
                    sb.sb_write_strobe <= 1'b1;
                    sb.sb_write_data <= data_fifo[fifo_read_head];
                    sb.sb_address <= BASE_ADDRESS + mc_channel_sequencer*CHANNEL_OFFSET + DESTINATION_OFFSET*dest_fifo[fifo_read_head];
                    if(mc_channel_sequencer == CHANNEL_NUMBER-1) begin
                        mc_operation <= 0;
                        fifo_read_head <= fifo_read_head + 1;
                        mc_channel_sequencer <= 0;
                    end else begin
                        mc_channel_sequencer <= mc_channel_sequencer+1;        
                    end
                    state <= wait_xbar;
                end
            endcase
        end
    end


endmodule