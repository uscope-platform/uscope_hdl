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
    parameter BVALID_LATENCY = 3
)(
    input wire        clock,
    input wire        reset,
    AXI.slave  axi_in
);


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
            axi_in.BRESP <= 2'b1;
        end else begin
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
  

endmodule