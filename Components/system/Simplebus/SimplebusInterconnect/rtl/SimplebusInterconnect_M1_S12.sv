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

module SimplebusInterconnect_M1_S12 #(
        parameter SLAVE_1_LOW = 32'h00000000,
        parameter SLAVE_1_HIGH = 32'hffffffff,
        parameter SLAVE_2_LOW = 32'h00000000,
        parameter SLAVE_2_HIGH = 32'hffffffff,
        parameter SLAVE_3_LOW = 32'h00000000,
        parameter SLAVE_3_HIGH = 32'hffffffff,
        parameter SLAVE_4_LOW = 32'h00000000,
        parameter SLAVE_4_HIGH = 32'hffffffff,
        parameter SLAVE_5_LOW = 32'h00000000,
        parameter SLAVE_5_HIGH = 32'hffffffff,
        parameter SLAVE_6_LOW = 32'h00000000,
        parameter SLAVE_6_HIGH = 32'hffffffff,
        parameter SLAVE_7_LOW = 32'h00000000,
        parameter SLAVE_7_HIGH = 32'hffffffff,
        parameter SLAVE_8_LOW = 32'h00000000,
        parameter SLAVE_8_HIGH = 32'hffffffff,
        parameter SLAVE_9_LOW = 32'h00000000,
        parameter SLAVE_9_HIGH = 32'hffffffff,
        parameter SLAVE_10_LOW = 32'h00000000,
        parameter SLAVE_10_HIGH = 32'hffffffff,
        parameter SLAVE_11_LOW = 32'h00000000,
        parameter SLAVE_11_HIGH = 32'hffffffff,
        parameter SLAVE_12_LOW = 32'h00000000,
        parameter SLAVE_12_HIGH = 32'hffffffff
    )(
        input wire clock,
        Simplebus.slave master,
        Simplebus.master slave_1,
        Simplebus.master slave_2,
        Simplebus.master slave_3,
        Simplebus.master slave_4,
        Simplebus.master slave_5,
        Simplebus.master slave_6,
        Simplebus.master slave_7,
        Simplebus.master slave_8,
        Simplebus.master slave_9,
        Simplebus.master slave_10,
        Simplebus.master slave_11,
        Simplebus.master slave_12 
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
        // SLAVE #5 CONNECTIONS
        if((master.sb_address>=SLAVE_5_LOW) && (master.sb_address<SLAVE_5_HIGH))begin
            slave_5.sb_address[31:0] <= master.sb_address[31:0];
            slave_5.sb_write_strobe <= master.sb_write_strobe;
            slave_5.sb_read_strobe <= master.sb_read_strobe;
            slave_5.sb_write_data[31:0] <= master.sb_write_data[31:0]; 
        end else begin
            slave_5.sb_address[31:0] <= 0;
            slave_5.sb_write_strobe <= 0;
            slave_5.sb_read_strobe <= 0;
            slave_5.sb_write_data[31:0] <= 0;
        end
        // SLAVE #6 CONNECTIONS
        if((master.sb_address>=SLAVE_6_LOW) && (master.sb_address<SLAVE_6_HIGH))begin
            slave_6.sb_address[31:0] <= master.sb_address[31:0];
            slave_6.sb_write_strobe <= master.sb_write_strobe;
            slave_6.sb_read_strobe <= master.sb_read_strobe;
            slave_6.sb_write_data[31:0] <= master.sb_write_data[31:0]; 
        end else begin
            slave_6.sb_address[31:0] <= 0;
            slave_6.sb_write_strobe <= 0;
            slave_6.sb_read_strobe <= 0;
            slave_6.sb_write_data[31:0] <= 0;
        end
        // SLAVE #7 CONNECTIONS
        if((master.sb_address>=SLAVE_7_LOW) && (master.sb_address<SLAVE_7_HIGH))begin
            slave_7.sb_address[31:0] <= master.sb_address[31:0];
            slave_7.sb_write_strobe <= master.sb_write_strobe;
            slave_7.sb_read_strobe <= master.sb_read_strobe;
            slave_7.sb_write_data[31:0] <= master.sb_write_data[31:0]; 
        end else begin
            slave_7.sb_address[31:0] <= 0;
            slave_7.sb_write_strobe <= 0;
            slave_7.sb_read_strobe <= 0;
            slave_7.sb_write_data[31:0] <= 0;
        end
        // SLAVE #8 CONNECTIONS
        if((master.sb_address>=SLAVE_8_LOW) && (master.sb_address<SLAVE_8_HIGH))begin
            slave_8.sb_address[31:0] <= master.sb_address[31:0];
            slave_8.sb_write_strobe <= master.sb_write_strobe;
            slave_8.sb_read_strobe <= master.sb_read_strobe;
            slave_8.sb_write_data[31:0] <= master.sb_write_data[31:0]; 
        end else begin
            slave_8.sb_address[31:0] <= 0;
            slave_8.sb_write_strobe <= 0;
            slave_8.sb_read_strobe <= 0;
            slave_8.sb_write_data[31:0] <= 0;
        end
        // SLAVE #9 CONNECTIONS
        if((master.sb_address>=SLAVE_9_LOW) && (master.sb_address<SLAVE_9_HIGH))begin
            slave_9.sb_address[31:0] <= master.sb_address[31:0];
            slave_9.sb_write_strobe <= master.sb_write_strobe;
            slave_9.sb_read_strobe <= master.sb_read_strobe;
            slave_9.sb_write_data[31:0] <= master.sb_write_data[31:0]; 
        end else begin
            slave_9.sb_address[31:0] <= 0;
            slave_9.sb_write_strobe <= 0;
            slave_9.sb_read_strobe <= 0;
            slave_9.sb_write_data[31:0] <= 0;
        end
        // SLAVE #10 CONNECTIONS
        if((master.sb_address>=SLAVE_10_LOW) && (master.sb_address<SLAVE_10_HIGH))begin
            slave_10.sb_address[31:0] <= master.sb_address[31:0];
            slave_10.sb_write_strobe <= master.sb_write_strobe;
            slave_10.sb_read_strobe <= master.sb_read_strobe;
            slave_10.sb_write_data[31:0] <= master.sb_write_data[31:0]; 
        end else begin
            slave_10.sb_address[31:0] <= 0;
            slave_10.sb_write_strobe <= 0;
            slave_10.sb_read_strobe <= 0;
            slave_10.sb_write_data[31:0] <= 0;
        end
        // SLAVE #11 CONNECTIONS
        if((master.sb_address>=SLAVE_11_LOW) && (master.sb_address<SLAVE_11_HIGH))begin
            slave_11.sb_address[31:0] <= master.sb_address[31:0];
            slave_11.sb_write_strobe <= master.sb_write_strobe;
            slave_11.sb_read_strobe <= master.sb_read_strobe;
            slave_11.sb_write_data[31:0] <= master.sb_write_data[31:0]; 
        end else begin
            slave_11.sb_address[31:0] <= 0;
            slave_11.sb_write_strobe <= 0;
            slave_11.sb_read_strobe <= 0;
            slave_11.sb_write_data[31:0] <= 0;
        end
        // SLAVE #12 CONNECTIONS
        if((master.sb_address>=SLAVE_12_LOW) && (master.sb_address<SLAVE_12_HIGH))begin
            slave_12.sb_address[31:0] <= master.sb_address[31:0];
            slave_12.sb_write_strobe <= master.sb_write_strobe;
            slave_12.sb_read_strobe <= master.sb_read_strobe;
            slave_12.sb_write_data[31:0] <= master.sb_write_data[31:0]; 
        end else begin
            slave_12.sb_address[31:0] <= 0;
            slave_12.sb_write_strobe <= 0;
            slave_12.sb_read_strobe <= 0;
            slave_12.sb_write_data[31:0] <= 0;
        end 

        master.sb_read_data[31:0] <= slave_1.sb_read_data[31:0] | slave_2.sb_read_data[31:0] | slave_3.sb_read_data[31:0] | slave_4.sb_read_data[31:0] | slave_5.sb_read_data[31:0] | slave_6.sb_read_data[31:0] | slave_7.sb_read_data[31:0] | slave_8.sb_read_data[31:0] | slave_9.sb_read_data[31:0] | slave_10.sb_read_data[31:0] | slave_11.sb_read_data[31:0] | slave_12.sb_read_data[31:0];
        master.sb_read_valid <= slave_1.sb_read_valid | slave_2.sb_read_valid | slave_3.sb_read_valid | slave_4.sb_read_valid | slave_5.sb_read_valid | slave_6.sb_read_valid | slave_7.sb_read_valid | slave_8.sb_read_valid | slave_9.sb_read_valid | slave_10.sb_read_valid | slave_11.sb_read_valid | slave_12.sb_read_valid;
        master.sb_ready <= slave_1.sb_ready & slave_2.sb_ready & slave_3.sb_ready & slave_4.sb_ready & slave_5.sb_ready & slave_6.sb_ready & slave_7.sb_ready & slave_8.sb_ready & slave_9.sb_ready & slave_10.sb_ready & slave_11.sb_ready & slave_12.sb_ready;
        
    end

endmodule