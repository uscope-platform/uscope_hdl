

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


module axis_packet_remapper #(
    parameter DATA_WIDTH= 32, 
    DEST_WIDTH = 8,
    USER_WIDTH = 8,
    PACKET_LENGTH = 3,
    DEST_BASE = 0
)(
    input wire        clock,
    input wire        reset,
    input wire        sync,
    axi_stream.slave in,
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

    reg[DATA_WIDTH-1:0] packet_data [PACKET_LENGTH-1:0];
    reg[DATA_WIDTH-1:0] packet_user [PACKET_LENGTH-1:0];
    

    always_ff@(posedge clock)begin
        if(registered_stream.valid)begin
            packet_data[registered_stream.dest - DEST_BASE] <= registered_stream.data;
            packet_user[registered_stream.dest - DEST_BASE] <= registered_stream.user;
        end
    end
    
    reg transmitting = 0;
    reg [15:0] packet_counter  = 0;

    assign registered_stream.ready = out.ready;
    always_ff@(posedge clock)begin
        if(~reset)begin
            out.valid <= 0;
            out.data <= 0;
            out.dest <= 0;
            out.user <= 0;
            out.tlast <= 0;
        end else begin
            if(sync)begin
                transmitting <= 1;

                out.data <= packet_data[0];
                out.dest <= 0;
                out.user <= packet_user[0];
                out.valid <= 1;
                out.tlast <= 0;

                packet_counter <= 1;
            end else if(transmitting)begin

                out.data <= packet_data[packet_counter];
                out.dest <= packet_counter;
                out.user <= packet_user[packet_counter];
                out.valid <= 1;
                if(packet_counter == PACKET_LENGTH-1)begin
                    packet_counter <= 0;
                    out.tlast <= 1;
                    transmitting <= 0;
                end else begin
                    out.tlast <= 0;
                    packet_counter <= packet_counter +1;
                end
                
            end else begin
            
                out.valid <= 0;
                out.tlast <= 0;
            end
        end
    end

endmodule