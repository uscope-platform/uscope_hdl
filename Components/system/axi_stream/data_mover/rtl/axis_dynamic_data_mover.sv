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

`timescale 10ns / 1ns
`include "interfaces.svh"

module axis_dynamic_data_mover #(
    parameter DATA_WIDTH = 32,
    MAX_CHANNELS=1,
    parameter PRAGMA_MKFG_DATAPOINT_NAMES = "",
    parameter OUTPUT_USER = get_axis_metadata(32, 0, 1),
    REPEAT_MODE = 0
)(
    input wire clock,
    input wire reset,
    input wire start,
    input wire repeat_outputs,
    output reg done,
    axi_stream.master data_request,
    axi_stream.slave data_response,
    axi_stream.master data_out,
    axi_lite.slave axi_in
);

    parameter N_REGISTERS = MAX_CHANNELS+1;

    reg [31:0] cu_write_registers [N_REGISTERS-1:0];
    reg [31:0] cu_read_registers [N_REGISTERS-1:0];
    

    wire [15:0] source_addr  [MAX_CHANNELS-1:0];
    wire [15:0] target_addr [MAX_CHANNELS-1:0];
    reg [$clog2(MAX_CHANNELS)-1:0] n_active_channels;

    localparam [31:0] INIT_VAL [N_REGISTERS-1:0] = '{default:0};
    

    axil_simple_register_cu #(
        .N_READ_REGISTERS(N_REGISTERS),
        .N_WRITE_REGISTERS(N_REGISTERS),
        .REGISTERS_WIDTH(32),
        .ADDRESS_MASK('hfff),
        .INITIAL_OUTPUT_VALUES(INIT_VAL)
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(cu_read_registers),
        .output_registers(cu_write_registers),
        .axil(axi_in)
    );

    assign cu_read_registers = cu_write_registers;
    
    assign n_active_channels = cu_write_registers[0];
    genvar n;
    generate
        for(n = 1; n<N_REGISTERS; n=n+1)begin
            assign source_addr[n-1] = cu_write_registers[n][15:0];
            assign target_addr[n-1] = cu_write_registers[n][31:16];
        end
    endgenerate

    reg [DATA_WIDTH-1:0] data_buffers [MAX_CHANNELS-1:0];


    reg mover_active;
    reg [$clog2(MAX_CHANNELS)-1:0] channel_sequencer;

    enum reg [2:0] { 
        idle = 0, 
        read_source = 1,
        wait_response = 2,
        send_buffered_data = 3,
        wait_ready = 4
    } sequencer_state;

    always_ff @(posedge clock) begin
        if(!reset) begin
            data_response.ready <= 1;
            data_out.valid <= 0;
            data_request.data <= 0;
            data_request.valid <= 0;
            data_out.data <= 0;
            data_out.user <= OUTPUT_USER;
            data_out.dest <= 0;
            channel_sequencer <= 0;
            mover_active <= 0;
            sequencer_state <= idle;
        end else begin
            data_out.valid <= 0;
            data_request.valid <= 0; 
            case (sequencer_state)
                idle :begin
                    done <= 0;
                    if(start) begin
                        sequencer_state <= read_source;
                    end
                    if(REPEAT_MODE==1 && repeat_outputs)begin
                        sequencer_state <= send_buffered_data;
                    end
                end 
                read_source: begin
                    data_request.data <= source_addr[channel_sequencer];
                    data_request.valid <= 1;  
                    sequencer_state <= wait_response;
                end
                wait_response: begin
                    if(data_response.valid)begin
                        data_out.data <= data_response.data;
                        data_buffers[channel_sequencer] <= data_response.data;
                        data_out.dest <= target_addr[channel_sequencer];
                        data_out.valid <= data_response.valid;
                        if(channel_sequencer == n_active_channels-1)begin
                            channel_sequencer <= 0;
                            done <= 1;
                            sequencer_state <= idle;
                        end else begin
                            channel_sequencer <= channel_sequencer + 1;
                            sequencer_state <= read_source;
                        end
                    end
                end
                send_buffered_data:begin
                        data_out.data <= data_buffers[channel_sequencer];
                        data_out.dest <= target_addr[channel_sequencer];
                        data_out.valid <= 1;
                        if(channel_sequencer == n_active_channels-1)begin
                            channel_sequencer <= 0;
                            done <= 1;
                            sequencer_state <= idle;
                        end else begin
                            channel_sequencer <= channel_sequencer + 1;
                            sequencer_state <= wait_ready;
                        end
                end
                wait_ready:begin
                    data_out.valid <= 0;
                    if(data_out.ready)begin
                        sequencer_state <= send_buffered_data;
                    end
                end
            endcase
        end
    end

endmodule



 /**
    {
        "name": "axis_dynamic_data_mover",
        "alias": "axis_dynamic_data_mover",
        "type": "parametric_peripheral",
        "registers":[
            {
                "name": "n_channels",
                "n_regs": ["1"],
                "description": "number of active DMA channels",
                "direction": "RW"
            },    
            {
                "name": "addr_$",
                "n_regs": ["MAX_STEPS"],
                "description": "This register selects source and target address for channel $",
                "direction": "RW",
                "fields":[
                     {
                        "name":"src",
                        "description": "Source address",
                        "n_fields":["1"],
                        "start_position": 0,
                        "length": 16
                    },
                    {
                        "name":"dst",
                        "description": "Destination address",
                        "start_position": 15,
                        "n_fields":["1"],
                        "length": 15
                    }
                ]
            }
        ]
    }   
 **/