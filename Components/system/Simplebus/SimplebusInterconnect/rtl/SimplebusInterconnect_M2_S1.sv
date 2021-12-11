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

module SimplebusInterconnect_M2_S1 #(
        parameter SLAVE_LOW = 32'h00000000,
        parameter SLAVE_HIGH = 32'hffffffff
    )(
        input wire clock,
        Simplebus.slave master_1,
        Simplebus.slave master_2, 
        Simplebus.master slave
    );

    reg [31:0] selected_address;
    reg        selected_read_strobe;
    reg        selected_write_strobe;
    reg [31:0] selected_write_data;

    always@(posedge clock) begin : master_selection
        if(master_1.sb_read_strobe | master_1.sb_write_strobe) begin
            selected_address <= master_1.sb_address;
            selected_read_strobe <= master_1.sb_read_strobe;
            selected_write_strobe <= master_1.sb_write_strobe;
            selected_write_data <= master_1.sb_write_data;
        end else if(master_2.sb_read_strobe | master_2.sb_write_strobe) begin
            selected_address <= master_2.sb_address;
            selected_read_strobe <= master_2.sb_read_strobe;
            selected_write_strobe <= master_2.sb_write_strobe;
            selected_write_data <= master_2.sb_write_data;
        end else begin
            selected_address <= 0;
            selected_read_strobe <= 0;
            selected_write_strobe <= 0;
            selected_write_data <= 0;
        end
    end

    always@(posedge clock) begin
        // SLAVE CONNECTIONS
        if((selected_address>=SLAVE_LOW) && (selected_address<SLAVE_HIGH))begin
            slave.sb_address[31:0] <= selected_address[31:0];
            slave.sb_write_strobe <= selected_write_strobe;
            slave.sb_read_strobe <= selected_read_strobe;
            slave.sb_write_data[31:0] <= selected_write_data[31:0]; 
        end else begin
            slave.sb_address[31:0] <= 0;
            slave.sb_write_strobe <= 0;
            slave.sb_read_strobe <= 0;
            slave.sb_write_data[31:0] <= 0;
        end
    end
    
    
        // MASTER #1 CONNECTIONS
        assign master_1.sb_read_data[31:0] = slave.sb_read_data[31:0];
        assign master_1.sb_read_valid = slave.sb_read_valid;
        assign master_1.sb_ready = slave.sb_ready;
        // MASTER #2 CONNECTIONS
        assign master_2.sb_read_data[31:0] = slave.sb_read_data[31:0];
        assign master_2.sb_read_valid = slave.sb_read_valid;
        assign master_2.sb_ready = slave.sb_ready;

endmodule