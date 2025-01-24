// Copyright 2025 Filippo Savi
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

module SyncEngine #(
    parameter N_CHAINS = 3
) (
    input wire clock,
    input wire enable,
    input wire [N_CHAINS-1:0] sync_in,
    input wire [15:0] sync_select,
    input wire [15:0] sync_delay,
    output reg sync_out
);


    wire selected_sync = sync_in[N_CHAINS - sync_select-1];

    reg wait_init = 1;

    reg[15:0] sync_delay_counter = 0;

    always_ff @(posedge clock)begin
        sync_out <= 0;
        if(enable)begin
            if(wait_init) begin
                if(~selected_sync)begin
                    wait_init <= 0;
                end
            end else begin
                if(selected_sync)begin
                    sync_delay_counter <=  sync_delay_counter+1;
                end
                if(sync_delay_counter >0) begin
                    if(sync_delay_counter == sync_delay-1)begin
                        sync_out <= 1;
                        sync_delay_counter <= 0;
                    end else begin
                        sync_delay_counter <=  sync_delay_counter +1;
                    end
                end
            end
            

        end
        
        
    end
    
endmodule