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

module SimplebusInterconnect_M1_S4 #(
        parameter SLAVE_1_LOW = 32'h00000000,
        parameter SLAVE_1_HIGH = 32'hffffffff,
        parameter SLAVE_2_LOW = 32'h00000000,
        parameter SLAVE_2_HIGH = 32'hffffffff,
        parameter SLAVE_3_LOW = 32'h00000000,
        parameter SLAVE_3_HIGH = 32'hffffffff,
        parameter SLAVE_4_LOW = 32'h00000000,
        parameter SLAVE_4_HIGH = 32'hffffffff
    )(
        input wire clock,
        Simplebus.slave master,
        Simplebus.master slave_1,
        Simplebus.master slave_2,
        Simplebus.master slave_3,
        Simplebus.master slave_4
    );


    always@(posedge clock) begin
        // SLAVE #1 CONNECTIONS
        if((master.sb_address>=SLAVE_1_LOW) && (master.sb_address<SLAVE_1_HIGH))begin
            slave_1.sb_address[31:0] <= master.sb_address[31:0];
            slave_1.sb_write_strobe <= master.sb_write_strobe;
            slave_1.sb_read_strobe <= master.sb_read_strobe;
            slave_1.sb_write_data[31:0] <= master.sb_write_data[31:0]; 
        end else begin
            slave_1.sb_address[31:0] <= 0;
            slave_1.sb_write_strobe <= 0;
            slave_1.sb_read_strobe <= 0;
            slave_1.sb_write_data[31:0] <= 0;
        end
        // SLAVE #2 CONNECTIONS
        if((master.sb_address>=SLAVE_2_LOW) && (master.sb_address<SLAVE_2_HIGH))begin
            slave_2.sb_address[31:0] <= master.sb_address[31:0];
            slave_2.sb_write_strobe <= master.sb_write_strobe;
            slave_2.sb_read_strobe <= master.sb_read_strobe;
            slave_2.sb_write_data[31:0] <= master.sb_write_data[31:0]; 
        end else begin
            slave_2.sb_address[31:0] <= 0;
            slave_2.sb_write_strobe <= 0;
            slave_2.sb_read_strobe <= 0;
            slave_2.sb_write_data[31:0] <= 0;
        end
        // SLAVE #3 CONNECTIONS
        if((master.sb_address>=SLAVE_3_LOW) && (master.sb_address<SLAVE_3_HIGH))begin
            slave_3.sb_address[31:0] <= master.sb_address[31:0];
            slave_3.sb_write_strobe <= master.sb_write_strobe;
            slave_3.sb_read_strobe <= master.sb_read_strobe;
            slave_3.sb_write_data[31:0] <= master.sb_write_data[31:0]; 
        end else begin
            slave_3.sb_address[31:0] <= 0;
            slave_3.sb_write_strobe <= 0;
            slave_3.sb_read_strobe <= 0;
            slave_3.sb_write_data[31:0] <= 0;
        end
        // SLAVE #4 CONNECTIONS
        if((master.sb_address>=SLAVE_4_LOW) && (master.sb_address<SLAVE_4_HIGH))begin
            slave_4.sb_address[31:0] <= master.sb_address[31:0];
            slave_4.sb_write_strobe <= master.sb_write_strobe;
            slave_4.sb_read_strobe <= master.sb_read_strobe;
            slave_4.sb_write_data[31:0] <= master.sb_write_data[31:0]; 
        end else begin
            slave_4.sb_address[31:0] <= 0;
            slave_4.sb_write_strobe <= 0;
            slave_4.sb_read_strobe <= 0;
            slave_4.sb_write_data[31:0] <= 0;
        end 

        master.sb_read_data[31:0] <= slave_1.sb_read_data[31:0] | slave_2.sb_read_data[31:0] | slave_3.sb_read_data[31:0] | slave_4.sb_read_data[31:0];
        master.sb_ready <= slave_1.sb_ready & slave_2.sb_ready & slave_3.sb_ready & slave_4.sb_ready;
    end

endmodule