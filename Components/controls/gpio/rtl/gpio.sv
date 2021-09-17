// Copyright (C) : 3/17/2019, 5:57:35 PM Filippo Savi - All Rights Reserved
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

module gpio #(parameter BASE_ADDRESS = 0,INPUT_WIDTH = 8,OUTPUT_WIDTH = 8)(
    input wire clock,
    input wire reset,
    input wire [INPUT_WIDTH-1:0] gpio_i,
    output reg [OUTPUT_WIDTH-1:0] gpio_o,
    Simplebus.slave sb
);

reg [7:0]  latched_adress;
reg [31:0] latched_writedata;
reg state;

localparam wait_state = 0, act_state = 1;

always @(posedge clock) begin
    if(~reset) begin
        latched_adress<=0;
        latched_writedata<=0;
    end else begin
        if(sb.sb_write_strobe) begin
            latched_adress <= sb.sb_address-BASE_ADDRESS;
            latched_writedata <= sb.sb_write_data;
        end else if(sb.sb_read_strobe) begin
            latched_adress <= sb.sb_address-BASE_ADDRESS;
        end else begin
            latched_adress <= latched_adress;
            latched_writedata <= latched_writedata;
        end
    end
end


// Determine the next state
always @ (posedge clock) begin
    if (~reset) begin
        sb.sb_ready <= 1'b1;
        state <= wait_state;
        sb.sb_read_data <= 0;
        gpio_o <= 0;
    end else begin
        case (state)
            wait_state: begin //wait for command
                if(sb.sb_read_strobe|sb.sb_write_strobe) begin
                    state <= act_state;
                    sb.sb_ready <= 1'b0;
                end else
                    state <= wait_state;
                end

            act_state:begin
                state <= wait_state;
                sb.sb_ready <= 1'b1;
            end 
        endcase

        //act if necessary
        case (state)
            act_state:
                case (latched_adress)
                    8'h0: begin  
                        gpio_o[OUTPUT_WIDTH-1:0] <= latched_writedata[OUTPUT_WIDTH-1:0];
                    end
                    8'h4: begin  
                        sb.sb_read_data <= gpio_i[INPUT_WIDTH-1:0];
                    end
                endcase
        endcase
    end
end


endmodule