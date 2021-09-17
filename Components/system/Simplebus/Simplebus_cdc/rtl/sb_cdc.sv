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


module sb_cdc (
    input wire in_clock,
    input wire out_clock,
    input wire reset,
    Simplebus.slave in_sb,
    Simplebus.master out_sb
);


    assign in_sb.sb_ready = 1;

    xpm_cdc_handshake #(
        .DEST_EXT_HSK(0),   // DECIMAL; 0=internal handshake, 1=external handshake
        .DEST_SYNC_FF(2),   // DECIMAL; range: 2-10
        .SRC_SYNC_FF(2),    // DECIMAL; range: 2-10
        .WIDTH(32)           // DECIMAL; range: 1-1024
    )
    data_cdc (
        .dest_out(out_sb.sb_write_data), 
        .dest_req(out_sb.sb_write_strobe),
        .dest_clk(out_clock),
        .src_clk(in_clock),  
        .src_in(in_sb.sb_write_data),
        .src_send(in_sb.sb_write_strobe) 
    );
    xpm_cdc_handshake #(
        .DEST_EXT_HSK(0),   // DECIMAL; 0=internal handshake, 1=external handshake
        .DEST_SYNC_FF(2),   // DECIMAL; range: 2-10
        .SRC_SYNC_FF(2),    // DECIMAL; range: 2-10
        .WIDTH(32)           // DECIMAL; range: 1-1024
    )
    address_cdc (
        .dest_out(out_sb.sb_address), 
        .dest_clk(out_clock),
        .src_clk(in_clock),  
        .src_in(in_sb.sb_address),
        .src_send(in_sb.sb_write_strobe) 
    );

    /*
    reg [$clog2(3)-1:0] fifo_addr_w;
    reg [$clog2(3)-1:0] fifo_addr_r;

    reg [31:0] write_data_fifo_memory[3:0];
    reg [31:0] write_addr_fifo_memory[3:0];
    integer i;

    always@(posedge in_clock) begin
        if(~reset)begin
            for(i = 0; i< 4; i = i+1)begin
                write_data_fifo_memory[i] = 0;
            end
            for(i = 0; i< 4; i = i+1)begin
                write_addr_fifo_memory[i] = 0;
            end 
            fifo_addr_w <=0;
            in_sb.sb_ready <= 1;
        end else begin
            if(in_sb.sb_write_strobe)begin
                write_data_fifo_memory[fifo_addr_w] <= in_sb.sb_write_data;
                write_addr_fifo_memory[fifo_addr_w] <= in_sb.sb_address;
                fifo_addr_w <= fifo_addr_w+1;
            end

        end
    end

    always@(posedge out_clock) begin
            if(~reset)begin
                out_sb.sb_write_data <= 0;
                out_sb.sb_write_strobe <= 0;
                out_sb.sb_address <= 0;
                fifo_addr_r <=0;
            end else begin
                if(out_sb.sb_write_strobe) begin
                    out_sb.sb_write_strobe <= 0;
                end else begin
                    if(fifo_addr_r != fifo_addr_w)begin
                        fifo_addr_r <= fifo_addr_r+1;
                        out_sb.sb_write_data  <= write_data_fifo_memory[fifo_addr_r];
                        out_sb.sb_address <= write_addr_fifo_memory[fifo_addr_r];
                        out_sb.sb_write_strobe <= 1;
                    end    
                end
                
            end
        end
*/
endmodule
