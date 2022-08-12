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

module fCore_ControlUnit #(parameter PC_WIDTH = 12, MAX_CHANNELS = 255)(
    input wire clock,
    input wire run,
    input wire immediate_advance,
    input wire efi_call,
    input wire efi_done,
    output reg efi_start,
    input wire core_stop,
    input wire [$clog2(MAX_CHANNELS)-1:0] n_channels,
    output reg [PC_WIDTH-1: 0] program_counter,
    output reg [$clog2(MAX_CHANNELS)-1:0] channel_address,
    output reg decoder_enable,
    output reg dma_enable,
    output reg done
    );

    reg [$clog2(MAX_CHANNELS)-1:0] channel_counter;


    always@(posedge clock)begin
        channel_address <= channel_counter;
    end

    enum reg [2:0] {IDLE = 3'b000,
                    PREFETCH = 3'b001,
                    RUN = 3'b010,
                    EFI_CALL = 3'b011
                    } state = IDLE;

    always@(posedge clock)begin
        case(state)
            IDLE:begin
                program_counter <= 0;
                channel_counter <= 0;
                decoder_enable <= 0;
                efi_start <= 0;
                done <= 0;
                dma_enable <= 1;
                if(run) begin
                    dma_enable <= 0;
                    state <= RUN;
                end
            end
            PREFETCH:begin
                state <= RUN;
                decoder_enable <= 1;
                dma_enable <= 0;
                program_counter <= program_counter+1;
            end
            RUN:begin
                dma_enable <= 0;
                decoder_enable <= 1;
                if(efi_call)begin
                    state <= EFI_CALL;
                    efi_start <= 1;
                end else if((channel_counter == n_channels-1) | immediate_advance)begin
                    program_counter <= program_counter+1;
                    channel_counter <= 0;
                end else begin
                    channel_counter <= channel_counter+1;
                end
                if(core_stop)begin
                    done <= 1;
                    state <= IDLE;
                end
            end
            EFI_CALL:begin
                efi_start <= 0;
                if(efi_done)begin
                    if((channel_counter == n_channels-1) | immediate_advance)begin
                        program_counter <= program_counter+1;
                        channel_counter <= 0;
                    end else begin
                        channel_counter <= channel_counter+1;
                    end
                    state <= RUN;
                end
            end
        endcase
    end

    
endmodule
