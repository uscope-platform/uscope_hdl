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

`ifndef SB_BFM_SV
`define SB_BFM_SV


class simplebus_BFM;

    virtual Simplebus.master spb;
    integer clock_period;


    function new (virtual Simplebus.master s, integer period);
        begin
            this.spb = s;
            this.spb.sb_address <= 32'b0;
            this.spb.sb_write_data <= 32'b0;
            this.spb.sb_write_strobe <= 1'b0;
            this.spb.sb_read_strobe <=1'b0;
            this.clock_period = period;
        end
    endfunction

    task write(input logic [31:0] address, write_data);
        wait(this.spb.sb_ready);
        this.spb.sb_address <= address;
        this.spb.sb_write_data <= write_data;
        this.spb.sb_write_strobe <= 1'b1;
        #(this.clock_period) this.spb.sb_write_strobe <= 1'b0;
        this.spb.sb_write_data <=0;
        @(posedge this.spb.sb_ready);
    endtask


    task write_nb(input logic [31:0] address, write_data);
        wait(this.spb.sb_ready);
        this.spb.sb_address <= address;
        this.spb.sb_write_data <= write_data;
        this.spb.sb_write_strobe <= 1'b1;
        #(this.clock_period) this.spb.sb_write_strobe <= 1'b0;
        this.spb.sb_write_data <=0;
    endtask
    
    task read(input logic [31:0] address, output logic [31:0] read_data);
        this.spb.sb_address <= address;
        this.spb.sb_read_strobe <= 1'b1;
        #(this.clock_period) this.spb.sb_read_strobe <= 1'b0;
        @(posedge this.spb.sb_read_valid) read_data = this.spb.sb_read_data;
    endtask
    
    task reset();
        this.spb.sb_address <= 32'b0;
        this.spb.sb_write_data <= 32'b0;
        this.spb.sb_write_strobe <= 1'b0;
        this.spb.sb_read_strobe <=1'b0;
    endtask

    task decode_write(output logic [31:0] address, output logic [31:0] write_data);
        @(posedge this.spb.sb_write_strobe);
        address = this.spb.sb_address;
        write_data = this.spb.sb_write_data;
    endtask

endclass

`endif