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



module sb_axis_dma_master #(
    parameter BASE_ADDRESS = 'h43c00000,
    CHANNEL_OFFSET = 'h0,
    DESTINATION_OFFSET = 'h0,
    CHANNEL_NUMBER = 3,
    SB_DELAY = 5,
    TARGET_ADDRESS = 'h18,
    parameter [7:0]SOURCE_CHANNEL_SEQUENCE [CHANNEL_NUMBER-1:0]= {3,2,1},
    parameter [7:0]TARGET_CHANNEL_SEQUENCE [CHANNEL_NUMBER-1:0]= {3,2,1}
)(
    input wire clock,
    input wire reset,
    input wire enable,
    Simplebus.master source,
    axi_stream.master target
);
    
    reg [$clog2(CHANNEL_NUMBER)-1:0] channel_sequencer;
    reg channel_counter_active;
    enum reg [1:0] { 
        idle = 0, 
        read_source = 1,
        write_target =2,
        wait_xbar =3
    } state;


    reg [$clog2(SB_DELAY)-1:0] wait_counter;
    always_ff @(posedge clock)begin
        if(~reset)begin
            state <= idle;
            wait_counter <= 0;
        end else begin
            if(channel_counter_active)begin
                case (state)
                    idle: begin
                        if(target.ready & source.sb_ready) begin
                            source.sb_address <= BASE_ADDRESS + (SOURCE_CHANNEL_SEQUENCE[channel_sequencer]-1)*CHANNEL_OFFSET + DESTINATION_OFFSET;
                            source.sb_read_strobe<=1;
                            state <= read_source;
                        end
                        target.data <= 0;
                        target.dest <= 0;
                        target.valid <= 0;
                    end 
                    read_source: begin
                        source.sb_read_strobe<=0;
                        channel_sequencer <= channel_sequencer+1;
                        state <= wait_xbar;
                    end
                    wait_xbar:begin
                        if(wait_counter==SB_DELAY-1)begin
                            state <= idle;
                            target.data <= {TARGET_ADDRESS, source.sb_read_data};
                            target.dest <= TARGET_CHANNEL_SEQUENCE[channel_sequencer-1];
                            target.valid <= 1;
                            if(channel_sequencer==CHANNEL_NUMBER)begin
                                channel_counter_active <= 0;
                            end
                            wait_counter <=0;    
                        end else begin
                            wait_counter <= wait_counter+1;
                        end 
                    end
                    default: begin
                        state <= idle;
                        channel_counter_active <= 0;
                    end
                endcase
            end else if(enable)begin
                channel_sequencer <= 0;
                channel_counter_active <= 1;
            end else begin
                channel_sequencer <= 0;
                channel_counter_active <= 0;
                source.sb_read_strobe <= 0;
                source.sb_write_strobe <= 0;
                source.sb_address <= 0;
                source.sb_write_data <= 0;
                target.valid <= 0;
                target.tlast <= 0;
                target.user <= 0;
                target.dest <= 0;
                target.data <= 0;
            end
            
        
        end
    end

endmodule