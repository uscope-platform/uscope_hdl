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

module AdcProcessingControlUnit #(
    STICKY_FAULT = 0,
    DATA_PATH_WIDTH = 16,
    FLTER_TAP_WIDTH = 16,
    N_CHANNELS = 4
)(
    input wire clock,
    input wire reset,
    input wire data_in_valid,
    axi_lite.slave axi_in,
    // COMPARATORS
    output reg signed [DATA_PATH_WIDTH-1:0] comparator_thresholds [0:7],
    output reg [1:0]  latch_mode,
    output reg [1:0]  clear_latch,
    input wire [1:0]  trip_high,
    input wire [1:0]  trip_low,
    // CALIBRATION
    output wire signed [DATA_PATH_WIDTH-1:0] offset [N_CHANNELS-1:0],
    output wire [DATA_PATH_WIDTH-1:0] shift [N_CHANNELS-1:0],
    output reg        shift_enable,
    output reg        fault,
    // FILTERING AND DECIMATION
    output reg [7:0]  decimation_ratio,
    output reg [7:0]  n_taps,
    output reg [FLTER_TAP_WIDTH-1:0] taps_data,
    output reg [7:0]  taps_addr,
    output reg taps_we,
    output reg linearizer_enable
);

    parameter N_SHIFT_REGS = N_CHANNELS/8+1;
    parameter N_COMPARE_REGS = 4;
    parameter N_REGISTERS = N_CHANNELS+N_COMPARE_REGS+N_SHIFT_REGS+3;
    parameter TAP_ADDR_REG = N_CHANNELS+N_COMPARE_REGS+N_SHIFT_REGS+2;

    reg clear_fault, disable_fault;
    reg [7:0] slow_fault_threshold;

    reg [31:0] cu_write_registers [N_REGISTERS-1:0];
    reg [31:0] cu_read_registers [N_REGISTERS-1:0];

    parameter N_ZERO_IV = N_REGISTERS-N_COMPARE_REGS;
    parameter [31:0] ZERO_IV [N_ZERO_IV-1:0] = '{N_ZERO_IV{32'h0}};
	parameter [31:0] COMPARE_IV [N_COMPARE_REGS-1:0] = '{N_COMPARE_REGS{32'hffff0000}};
    parameter [31:0] IV [N_REGISTERS-1:0] = {ZERO_IV, COMPARE_IV};
    axil_simple_register_cu #(
        .N_READ_REGISTERS(N_REGISTERS),
        .N_WRITE_REGISTERS(N_REGISTERS),
        .REGISTERS_WIDTH(32),
        .ADDRESS_MASK('hff),
        .N_TRIGGER_REGISTERS(1),
        .TRIGGER_REGISTERS_IDX('{TAP_ADDR_REG}),
        .INITIAL_OUTPUT_VALUES(IV)
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(cu_read_registers),
        .output_registers(cu_write_registers),
        .trigger_out(taps_we),
        .axil(axi_in)
    );
    
    genvar i, j;
    generate

       
        for(i = 0; i<4; i++)begin
            assign comparator_thresholds[i] =  cu_write_registers[i][15:0];
            assign comparator_thresholds[i+4] =  cu_write_registers[i][31:16];
        end


        for(i = 0; i<N_CHANNELS; i++)begin
            assign offset[i] =  cu_write_registers[i+N_COMPARE_REGS][15:0];
        end
        for(j = 0; j<N_SHIFT_REGS; j++)begin
            for(i = 0; i<8; i++)begin
                if(i+j*8<N_CHANNELS)begin
                    assign shift[i+j*8] = cu_write_registers[N_CHANNELS+N_COMPARE_REGS+j][i*4+3:i*4];
                end
            end
        end
        
    endgenerate

    assign shift_enable         = cu_write_registers[N_CHANNELS+N_COMPARE_REGS+N_SHIFT_REGS][0];
    assign latch_mode           = cu_write_registers[N_CHANNELS+N_COMPARE_REGS+N_SHIFT_REGS][2:1];
    assign clear_latch          = cu_write_registers[N_CHANNELS+N_COMPARE_REGS+N_SHIFT_REGS][4:3];
    assign clear_fault          = cu_write_registers[N_CHANNELS+N_COMPARE_REGS+N_SHIFT_REGS][5];
    assign disable_fault        = cu_write_registers[N_CHANNELS+N_COMPARE_REGS+N_SHIFT_REGS][6];
    assign linearizer_enable    = cu_write_registers[N_CHANNELS+N_COMPARE_REGS+N_SHIFT_REGS][7];
    assign slow_fault_threshold = cu_write_registers[N_CHANNELS+N_COMPARE_REGS+N_SHIFT_REGS][15:8];
    assign n_taps               = cu_write_registers[N_CHANNELS+N_COMPARE_REGS+N_SHIFT_REGS][23:16];
    assign decimation_ratio     = cu_write_registers[N_CHANNELS+N_COMPARE_REGS+N_SHIFT_REGS][31:24];
    
    assign taps_data = cu_write_registers[N_CHANNELS+N_COMPARE_REGS+N_SHIFT_REGS+1];
    assign taps_addr = cu_write_registers[N_CHANNELS+N_COMPARE_REGS+N_SHIFT_REGS+2];

    assign cu_read_registers = cu_write_registers;
    
    reg arm_fault;

    reg [7:0] slow_fault_counter;
    

    always_ff@(posedge clock)begin
        if(~reset | disable_fault)begin
            arm_fault <= 0; 
        end else begin
            if(data_in_valid)begin
                arm_fault <= 1;
            end    
        end
        
    end

    generate
        if(STICKY_FAULT==0) begin
            always_comb begin
                fault <= trip_high[0] | trip_low[0] | trip_high[1] | trip_low[1];
            end       
        end else begin
            always @(posedge clock) begin : fault_trip
                if(~reset | ~arm_fault) begin
                    fault <= 0;
                    slow_fault_counter <= 0;
                end else begin
                    if(trip_high[0] | trip_low[0])begin
                        fault <= 1;
                    end else if (trip_high[1] | trip_low[1]) begin
                        if(slow_fault_counter == slow_fault_threshold-1)begin
                            fault <= 1;
                        end else begin
                            slow_fault_counter <= slow_fault_counter +1;    
                        end                
                    end else if(clear_fault)begin
                        fault <= 0;
                    end
                end
            end        
        end
    endgenerate

endmodule


 /**
    {
        "name": "AdcProcessingControlUnit",
        "alias": "AdcProcessing",
        "type": "peripheral",
        "registers":[
            {
                "name": "cmp_low_f",
                "offset": "0x0",
                "description": "Low comparator threshold (falling when in normal mode)",
                "direction": "RW",
                "fields":[
                    {
                        "name":"fast",
                        "description": "Fast comparator treshold",
                        "start_position": 0,
                        "length": 16
                    },
                    {
                        "name":"slow",
                        "description": "Slow comparator threshold",
                        "start_position": 16,
                        "length": 16
                    }
                ]
            },
            {
                "name": "cmp_low_r",
                "offset": "0x4",
                "description": "Low and rising comparator threshold in normal mode",
                "direction": "RW",
                "fields":[
                    {
                        "name":"fast",
                        "description": "Fast comparator treshold",
                        "start_position": 0,
                        "length": 16
                    },
                    {
                        "name":"slow",
                        "description": "Slow comparator threshold",
                        "start_position": 16,
                        "length": 16
                    }
                ]
            },
            {
                "name": "cmp_high_f",
                "offset": "0x8",
                "description": "high and falling comparator threshold in normal mode",
                "direction": "RW",
                "fields":[
                    {
                        "name":"fast",
                        "description": "Fast comparator treshold",
                        "start_position": 0,
                        "length": 16
                    },
                    {
                        "name":"slow",
                        "description": "Slow comparator threshold",
                        "start_position": 16,
                        "length": 16
                    }
                ]
            },
            {
                "name": "cmp_h_r",
                "offset": "0xc",
                "description": "High comparator threshold (rising in normal mode)",
                "direction": "RW",
                "fields":[
                    {
                        "name":"fast",
                        "description": "Fast comparator treshold",
                        "start_position": 0,
                        "length": 16
                    },
                    {
                        "name":"slow",
                        "description": "Slow comparator threshold",
                        "start_position": 16,
                        "length": 16
                    }
                ]
            },
            {
                "name": "cal_coeff",
                "offset": "0x10",
                "description": "Calibration coefficients",
                "direction": "RW",
                "fields":[
                    {
                        "name":"offset",
                        "description": "Fast comparator treshold",
                        "start_position": 16,
                        "length": 16
                    }
                ]
            },
            {
                "name": "control",
                "offset": "0x14",
                "description": "ADC post processing module control register",
                "direction": "RW",
                "fields":[
                    {
                        "name":"shift_enable",
                        "description": "Enables calibration shifter",
                        "start_position": 0,
                        "length": 1
                    },
                    {
                        "name":"latch_mode",
                        "description": "Toggles comparators between normal and latching mode",
                        "start_position": 1,
                        "length": 2
                    },
                    {
                        "name":"clear_latch",
                        "description": "Clear comparators latch when in latching mode",
                        "start_position": 3,
                        "length": 2
                    },
                    {
                        "name":"clear_fault",
                        "description": "Clear sticky fault satus",
                        "start_position": 5,
                        "length": 1
                    },
                    {
                        "name":"fault_disable",
                        "description": "Disable fault generation",
                        "start_position": 6,
                        "length": 1
                    },
                    {
                        "name":"fault_delay",
                        "description": "Amount of clock cycles a slow comparator must be active before triggering a fault",
                        "start_position": 8,
                        "length": 8
                    },
                    {
                        "name":"n_taps",
                        "description": "Number of active FIR filter taps",
                        "start_position": 8,
                        "length": 8
                    },
                    {
                        "name":"decimation",
                        "description": "Decimation ratio between input and output data",
                        "start_position": 24,
                        "length": 8
                    }
                ]
            },
            {
                "name": "filter_tap_data",
                "offset": "0x14",
                "description": "FIR filter coefficient interface data",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "filter_tap_address",
                "offset": "0x18",
                "description": "FIR filter coefficient interface address",
                "direction": "RW",
                "fields":[]
            }
        ]
    }   
    **/