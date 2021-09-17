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

`timescale 1ns / 1ps
`include "interfaces.svh"


module APB_to_Simplebus#(parameter READ_LATENCY = 2)(
    input logic PCLK,
    input logic PRESETn,
    APB.slave apb,
    Simplebus.master spb
    );

    
    localparam IDLE = 3'b001;
    localparam WAIT_LATENCY = 3'b010;
    localparam WAIT_ACK = 3'b100;

    reg [2:0] state = IDLE;
    reg [8:0] latency_counter;

    always@(posedge PCLK)begin
        if(~PRESETn)begin
            state <= IDLE;
            apb.PREADY <= 1;
            latency_counter <= READ_LATENCY;
        end else begin
            if(state == IDLE)begin
                if(apb.PSEL & ~apb.PENABLE & ~apb.PWRITE)begin
                    state <= WAIT_LATENCY;
                    apb.PREADY <= 0;
                end
            end else if (state == WAIT_LATENCY)begin
                if(latency_counter == 0)begin
                    apb.PRDATA <= spb.sb_read_data;
                    apb.PREADY <=1;
                    state <= IDLE;
                    latency_counter <= READ_LATENCY;
                end else begin
                    latency_counter <= latency_counter-1;
                end
            end
        end
    end


    always_comb begin
        if (~PRESETn) begin
            apb.PSLVERR <= 0;
            spb.sb_address <= 32'b0;
            spb.sb_read_strobe <= 1'b0;
            spb.sb_write_strobe <= 1'b0;
            spb.sb_write_data <= 32'b0;
        end else begin
            apb.PSLVERR <= 0;
            if (~apb.PSEL & ~apb.PENABLE) begin
                spb.sb_write_data <= 0;
                spb.sb_address <= 32'b0;
                spb.sb_read_strobe <= 1'b0;
                spb.sb_write_strobe <= 1'b0;
            end else if (apb.PSEL & ~apb.PENABLE) begin
                if (apb.PWRITE) begin
                    spb.sb_address <= apb.PADDR;
                    spb.sb_write_data <= apb.PWDATA;
                    spb.sb_write_strobe <= 1;
                    spb.sb_read_strobe <= 0;
                end else begin
                    spb.sb_write_data <= 0;
                    spb.sb_write_strobe <=0;
                    spb.sb_address <= apb.PADDR;
                    spb.sb_read_strobe <= 1;
                end
            end else begin
                spb.sb_address <= 32'b0;
                spb.sb_write_strobe <= 0;
                spb.sb_read_strobe <=0;
                spb.sb_write_data <= 0;
            end
        end
   end
endmodule
