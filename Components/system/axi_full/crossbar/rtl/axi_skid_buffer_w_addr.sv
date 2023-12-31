// Copyright 2021 Filippo Savi
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

module axi_w_addr_skid_buffer #(
    parameter REGISTER_OUTPUT = 1,
    parameter ADDR_WIDTH = 32,
    parameter ID_WIDTH = 32
) (
    input wire clock,
    input wire reset,
    input wire in_valid,
    output wire in_ready,
    input wire [ID_WIDTH-1:0] in_id,
    input wire [ADDR_WIDTH-1:0] in_addr,
    input wire [7:0] in_len,
    input wire [2:0] in_size,
    input wire [1:0] in_burst,
    input wire [1:0] in_lock,
    input wire [3:0] in_cache,
    input wire [2:0] in_prot,
    input wire [3:0] in_qos,
    
    output wire out_valid,
    input wire out_ready,

    output reg [ID_WIDTH-1:0] out_id,
    output reg [ADDR_WIDTH-1:0] out_addr,
    output reg [7:0] out_len,
    output reg [2:0] out_size,
    output reg [1:0] out_burst,
    output reg [1:0] out_lock,
    output reg [3:0] out_cache,
    output reg [2:0] out_prot,
    output reg [3:0] out_qos

);


    // If the output is stalled the input needs to be temporarily saved in the skid buffer;

    wire input_data_available;
    assign input_data_available = in_valid && in_ready;
    wire output_stalled;
    assign output_stalled = out_valid && !out_ready;

    reg input_skidding = 0;

    always_ff @(posedge clock) begin
        if (~reset) begin
            input_skidding <= 0;
        end else if (input_data_available && output_stalled) begin
            input_skidding <= 1;
        end else if (out_ready) begin
            input_skidding <= 0;
        end
    end
    

    reg registered_ready_reset;

    always_ff @(posedge clock) begin
        registered_ready_reset <= reset;
    end

    assign in_ready = registered_ready_reset & !input_skidding;

    reg	[ID_WIDTH-1:0] id_buffer = 0;
    reg	[ADDR_WIDTH-1:0] addr_buffer = 0;
    reg	[7:0] len_buffer = 0;
    reg	[2:0] size_buffer = 0;
    reg	[1:0] burst_buffer = 0;
    reg	[1:0] lock_buffer = 0;
    reg	[3:0] cache_buffer = 0;
    reg	[2:0] prot_buffer = 0;
    reg	[3:0] qos_buffer = 0;


    // manage buffer
    always_ff @(posedge clock) begin
        if (~reset) begin
            id_buffer <= 0;
            addr_buffer <= 0;
            len_buffer <= 0;
            size_buffer <= 0;
            burst_buffer <= 0;
            lock_buffer <= 0;
            cache_buffer <= 0;
            prot_buffer <= 0;
            qos_buffer <= 0;
        end else if(in_ready) begin
            id_buffer <= in_id;
            addr_buffer <= in_addr;
            len_buffer <= in_len;
            size_buffer <= in_size;
            burst_buffer <= in_burst;
            lock_buffer <= in_lock;
            cache_buffer <= in_cache;
            prot_buffer <= in_prot;
            qos_buffer <= in_qos;
        end
    end

    generate
        if (!REGISTER_OUTPUT ) begin
            // Outputs are combinatorially determined from inputs
            assign	out_valid = reset && (in_valid || input_skidding);
    
            always_comb begin
                if(input_skidding) begin
                    out_id = id_buffer;
                    out_addr = addr_buffer;
                    out_len = len_buffer;
                    out_size = size_buffer;
                    out_burst = burst_buffer;
                    out_lock = lock_buffer;
                    out_cache = cache_buffer;
                    out_prot = prot_buffer;
                    out_qos = qos_buffer;
                end else if(in_valid) begin
                    out_id = in_id;
                    out_addr = in_addr;
                    out_len = in_len;
                    out_size = in_size;
                    out_burst = in_burst;
                    out_lock = in_lock;
                    out_cache = in_cache;
                    out_prot = in_prot;
                    out_qos = in_qos;
                end else begin  
                    out_id = 0;
                    out_addr = 0;
                    out_len = 0;
                    out_size = 0;
                    out_burst = 0;
                    out_lock = 0;
                    out_cache = 0;
                    out_prot = 0;
                    out_qos = 0;
                end
            end
            
        end else begin
            // Register our outputs
            reg	registerd_valid = 0;
    
            always_ff @(posedge clock) begin
                if (~reset) begin
                    registerd_valid <= 0;
                end if (!out_valid || out_ready) begin
                    registerd_valid <= (in_valid || input_skidding); 
                end
            end
            
            assign	out_valid = registerd_valid;
    
            always_ff @(posedge clock) begin
                if (~reset) begin
                    out_id <= 0;
                    out_addr <= 0;
                    out_len <= 0;
                    out_size <= 0;
                    out_burst <= 0;
                    out_lock <= 0;
                    out_cache <= 0;
                    out_prot <= 0;
                    out_qos <= 0;
                end else if (!out_valid || out_ready) begin
                    if (input_skidding) begin
                        out_id <= id_buffer;
                        out_addr <= addr_buffer;
                        out_len <= len_buffer;
                        out_size <= size_buffer;
                        out_burst <= burst_buffer;
                        out_lock <= lock_buffer;
                        out_cache <= cache_buffer;
                        out_prot <= prot_buffer;
                        out_qos <= qos_buffer;
                    end else begin
                        out_id <= in_id;
                        out_addr <= in_addr;
                        out_len <= in_len;
                        out_size <= in_size;
                        out_burst <= in_burst;
                        out_lock <= in_lock;
                        out_cache <= in_cache;
                        out_prot <= in_prot;
                        out_qos <= in_qos;
                    end
                end
            end
        end
    endgenerate

endmodule