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


module fCore_dma_endpoint #(parameter BASE_ADDRESS = 32'h43c00000, DATAPATH_WIDTH = 20 ,PULSE_STRETCH_LENGTH = 6, REG_ADDR_WIDTH = 8, LEGACY_READ=1)(
    input wire clock,
    input wire reset,
    Simplebus.slave sb,
    output reg [REG_ADDR_WIDTH-1:0] dma_write_addr,
    output reg [DATAPATH_WIDTH-1:0] dma_write_data,
    output reg dma_write_valid,
    output reg [REG_ADDR_WIDTH:0] dma_read_addr,
    input wire [DATAPATH_WIDTH-1:0] dma_read_data,
    output reg [REG_ADDR_WIDTH-1:0] n_channels,
    axi_stream.slave axis_dma
    );



    //FSM state registers
   
    enum reg [2:0] {wait_state = 3'b000,
                    act_write = 3'b001,
                    act_read = 3'b010,
                    pulse_stretch = 3'b011,
                    wait_read = 3'b100
                    } state = wait_state;


    reg read_data_blanking;
    reg act_state_ended=0;
    reg [31:0] int_readdata; 
    reg [31:0]  latched_address;
    reg [31:0] latched_writedata;
    reg [7:0] pulse_stretch_cntr;

    assign sb.sb_read_data = int_readdata;
    

    //latch bus writes
    always @(posedge clock or negedge reset) begin
        if(~reset) begin
            latched_address<=0;
            latched_writedata<=0;
        end else begin
            if(sb.sb_write_strobe & state == wait_state) begin
                latched_address <= sb.sb_address-BASE_ADDRESS;
                latched_writedata <= sb.sb_write_data;
            end else begin
                latched_address <= latched_address;
                latched_writedata <= latched_writedata;
            end
        end
    end


    // Determine the next state
    always @ (posedge clock) begin
        dma_write_valid <= 0;
        int_readdata <= 0;
        sb.sb_read_valid <= 0;
        case (state)
            wait_state: begin //wait for command
                if(sb.sb_write_strobe) begin
                    sb.sb_ready <= 1'b0;
                    state <= act_write;
                end else if(sb.sb_read_strobe & sb.sb_address>4)begin
                    sb.sb_ready <= 0;
                    dma_read_addr <= (sb.sb_address-(BASE_ADDRESS+4))>>2;
                    state <= wait_read;
                    pulse_stretch_cntr <= 0;
                end else begin
                    sb.sb_ready <= 1;
                    read_data_blanking <= 1;
                    dma_write_addr <= 0;
                    state <=wait_state;
                    dma_read_addr <= 0;
                    dma_write_valid <= 0;
                    dma_write_data <= 0;
                end
            end
            
            act_write: begin // Act on shadowed write
                if(act_state_ended) begin
                    state <= wait_state;
                end else begin
                    state <= act_write;
                end
            end
            wait_read: begin
                state <= act_read;
            end

            act_read:begin
                state <= pulse_stretch;
            end
            
            pulse_stretch: begin // Act on shadowed write
                if(pulse_stretch_cntr == PULSE_STRETCH_LENGTH-1)begin
                    state <= wait_state;
                end else begin
                    state <= pulse_stretch;
                    pulse_stretch_cntr <= pulse_stretch_cntr+1;
                end
            end


        endcase

        //act if necessary
        case (state)
            wait_state: begin 
                dma_write_valid <= 0;
                act_state_ended <= 0;
            end

            act_write: begin
                if(latched_address<'h4)begin
                    n_channels <= latched_writedata[7:0];
                    act_state_ended <= 1;
                end else begin
                    dma_write_addr <= (latched_address-'h4)>>2;
                    dma_write_data <= latched_writedata;
                    dma_write_valid <= 1;
                    act_state_ended <= 1;
                end
                
            end
    
            act_read: begin
                
                if(latched_address<'h4)begin
                    int_readdata <= n_channels;
                end else begin
                    int_readdata <= dma_read_data[31:0];
                end
                sb.sb_read_valid <= 1;
                act_state_ended <= 1;
            end
        endcase

        if(axis_dma.valid)begin
            dma_write_addr <= axis_dma.dest;
            dma_write_data <= axis_dma.data;
            dma_write_valid <= 1;
        end
    end


endmodule
 