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

module stream_fault_detector(
    input wire clock,
    input wire reset,
    axi_stream.watcher  data_in,
    axi_lite.slave    axi_in,
    input wire clear_fault,
    output reg        fault
);

    reg [31:0] cu_write_registers [4:0];
    reg [31:0] cu_read_registers  [4:0];


    axil_simple_register_cu #(
        .N_READ_REGISTERS(5),
        .N_WRITE_REGISTERS(5),
        .REGISTERS_WIDTH(32),
        .ADDRESS_MASK('hff)
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(cu_read_registers),
        .output_registers(cu_write_registers),
        .axil(axi_in)
    );



    wire signed [31:0] fast_thresholds [1:0];
    wire signed [31:0] slow_thresholds [1:0];
    wire [7:0] slow_trip_duration;

    assign slow_thresholds[0] = cu_write_registers[0][31:0];
    assign slow_thresholds[1] = cu_write_registers[1][31:0];
    assign slow_trip_duration = cu_write_registers[2][7:0];
    assign fast_thresholds[0] = cu_write_registers[3][31:0];
    assign fast_thresholds[1] = cu_write_registers[4][31:0];

    assign cu_read_registers = cu_write_registers;


    reg latched = 0;
    
    wire signed[data_in.DATA_WIDTH-1:0] signed_data;
    assign signed_data = $signed(data_in.data);

    reg [7:0] slow_trip_counter = 0;

    always @(posedge clock) begin
        if(~reset)begin
            fault <= 0;
        end else begin
            if(latched)begin
                if(clear_fault)begin
                    latched <= 0; 
                    fault <= 0;
                    slow_trip_counter <= 0;
                end
            end else begin
                if(data_in.valid) begin
                    if(signed_data < fast_thresholds[0]) begin
                        fault <= 1;
                        latched <=1;
                    end 

                    if(signed_data > fast_thresholds[1]) begin
                        fault <= 1;
                        latched <=1;
                    end 

                    if(signed_data < slow_thresholds[0] || signed_data > slow_thresholds[1]) begin
                        slow_trip_counter <= slow_trip_counter + 1;
                    end 
                end
                    if(slow_trip_counter==slow_trip_duration && slow_trip_duration != 0) begin
                        fault <= 1;
                        latched <= 1;
                    end  
            end
        end
    end



endmodule
