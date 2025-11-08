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


module axi_lite_slave_sink (
    input wire        clock,
    input wire        reset,
    axi_lite.slave  axil_in
);


    always @( posedge clock ) begin : wready_generation
        if ( reset == 1'b0 ) begin
            axil_in.WREADY <= 1'b1;
            axil_in.AWREADY <= 1'b1;
            axil_in.ARREADY <= 1'b1;
        end else begin    
        end 
    end       




    always @( posedge clock ) begin : write_response_generation
        if ( reset == 1'b0 ) begin
            axil_in.BVALID <= 0;
            axil_in.BRESP <= 2'b1;
        end else if (axil_in.WVALID && axil_in.WREADY)
            axil_in.BVALID <= 1;
        else
        axil_in.BVALID <= 0;
    end   
  

endmodule