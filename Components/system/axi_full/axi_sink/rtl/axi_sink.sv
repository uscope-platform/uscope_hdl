// Copyright 2024 Filippo Savi
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


module axi_full_slave_sink #(
    parameter BUFFER_SIZE = 6144,
    parameter MEMORY_WIDTH = 64,
    parameter BASE_ADDRESS = 0,
    parameter BVALID_LATENCY = 3
)(
    input wire        clock,
    input wire        reset,
    AXI.slave  axi_in
);

    reg [15:0] burst_counter = 0;

    reg [31:0] current_base_address = 0;
    reg [7:0] burst_address = 0;
    
    reg [31:0] current_address;
    assign current_address = current_base_address  + burst_address*8;

    wire [31:0] memory_index;
    assign memory_index = (current_address - BASE_ADDRESS)/8;
     

    reg [MEMORY_WIDTH-1:0] memory_map [BUFFER_SIZE-1:0];

    always @( posedge clock ) begin : wready_generation
        if ( reset == 1'b0 ) begin
            axi_in.WREADY <= 1'b1;
            axi_in.AWREADY <= 1'b1;
            axi_in.ARREADY <= 1'b1;
        end else begin    
        end 
    end       

    reg bvalid_wait = 0;
    reg [7:0] bvalid_counter = 0;


    always @( posedge clock ) begin : write_response_generation
        if ( reset == 1'b0 ) begin
            axi_in.BVALID <= 0;
            axi_in.BID <= 0;
            axi_in.BUSER <= 0;
            axi_in.BRESP <= 2'b0;
        end else begin
            if(axi_in.AWVALID)begin
                current_base_address <= axi_in.AWADDR;
                burst_address <= 0;
                burst_counter++;
            end
            if(axi_in.WVALID)begin
                burst_address <= burst_address +1;
                memory_map[memory_index] <= axi_in.WDATA;
            end
            axi_in.BVALID <= 0;
            case (bvalid_wait)
                0:begin
                    if(axi_in.WVALID && axi_in.WREADY)begin
                        bvalid_wait <=1;
                        bvalid_counter <= 0;
                    end
                end
                1:begin
                    if(bvalid_counter == BVALID_LATENCY-1)begin
                        axi_in.BVALID <= 1;
                        bvalid_wait <= 0;
                    end else begin
                        bvalid_counter <= bvalid_counter+1;
                    end
                end 
            endcase
        end 
    end   
  
    integer transfers_counter = 0;

    always_ff @(posedge clock)begin
        if(transfers_counter == BUFFER_SIZE)
            transfers_counter <= 0;
        if(axi_in.WVALID && axi_in.WREADY)
            transfers_counter++;
    end

endmodule