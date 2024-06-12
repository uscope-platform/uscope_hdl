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
    parameter BVALID_LATENCY = 3,
    parameter ADDR_TO_WREADY_LATENCY = 2
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



    enum reg [2:0] {
        wait_addr = 0,       
        addr_to_data_latency = 1,
        data_transfer = 2,
        response_latency = 3
    } transfer_stage = wait_addr;


    reg [15:0] addr_to_ready_ctr = 0;
    reg [15:0] burst_ctr = 0;
    reg [7:0] burst_len = 0;
    reg [15:0] bvalid_ctr = 0;


    initial begin
        axi_in.WREADY <= 1'b0;
        axi_in.AWREADY <= 1'b1;
        axi_in.ARREADY <= 1'b1;
        axi_in.BRESP <= 0;
    end

    always @( posedge clock ) begin : wready_generation
        case(transfer_stage)
            wait_addr:begin
                axi_in.BVALID <= 0;
                if(axi_in.AWVALID) begin
                    transfer_stage <= addr_to_data_latency;
                    burst_len <= axi_in.AWLEN;
                end
            end
            addr_to_data_latency:begin
                if(addr_to_ready_ctr == ADDR_TO_WREADY_LATENCY-1)begin
                    transfer_stage <= data_transfer;
                    addr_to_ready_ctr <= 0;
                    axi_in.WREADY <= 1'b1;
                end else begin
                    addr_to_ready_ctr <= addr_to_ready_ctr + 1;
                end
            end
            data_transfer:begin
                if(burst_ctr == burst_len)begin
                    if(axi_in.WLAST)begin
                        transfer_stage <= response_latency;
                        axi_in.WREADY <= 1'b0;
                        burst_ctr <= 0;
                    end
                end else begin
                    if(axi_in.WVALID & axi_in.WREADY) begin
                        burst_ctr <= burst_ctr + 1;
                    end
                end
            end
            response_latency:begin
                if(bvalid_ctr == BVALID_LATENCY)begin
                    axi_in.BVALID <= 1;
                    bvalid_ctr <= 0;
                    transfer_stage <= wait_addr;
                end else begin
                    bvalid_ctr <= bvalid_ctr + 1;
                end
            end
        endcase
    end       

  
    integer transfers_counter = 0;

    always_ff @(posedge clock)begin
        if(transfers_counter == BUFFER_SIZE)
            transfers_counter <= 0;
        if(axi_in.WVALID && axi_in.WREADY)
            transfers_counter++;
    end

endmodule