
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


module axi_slave_sink (
    input wire        clock,
    input wire        reset,
    AXI.slave  axi,
    output reg [31:0] write_addr,
    output reg [31:0] write_data,
    output reg [31:0] read_addr,
    input reg [31:0] read_data
);


    reg axi_awv_awr_flag;
    reg axi_arv_arr_flag; 




    assign axi.BID = axi.AWID;
    assign axi.RID = axi.ARID; 


    always @( posedge clock ) begin : wready_generation
        if ( reset == 1'b0 ) begin
            axi.WREADY <= 1'b1;
            axi.AWREADY <= 1'b1;
            axi.ARREADY <= 1'b1;
        end else begin    
        end 
    end       
    

    always @( posedge clock ) begin 
        if(axi.AWVALID) write_addr <= axi.AWADDR;
        if(axi.WVALID) write_data <= axi.WDATA;
        if(axi.ARADDR) read_addr <= axi.ARADDR;
    end




    always @( posedge clock ) begin : write_response_generation
        if ( reset == 1'b0 ) begin
            axi.BVALID <= 0;
            axi.BRESP <= 2'b1;
            axi.BUSER <= 0;
        end else if (axi.WVALID && axi.WREADY && axi.WLAST)
            axi.BVALID <= 1;
        else
        axi.BVALID <= 0;
    end   
  

endmodule