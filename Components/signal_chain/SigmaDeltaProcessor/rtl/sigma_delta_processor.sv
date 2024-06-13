// Copyright 2023 Filippo Savi
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

module sigma_delta_processor #(
    parameter N_CHANNELS = 2,
    parameter MAIN_DECIMATION_RATIO = 256,
    parameter COMPARATOR_DECIMATION_RATIO = 256,
    parameter SAMPLING_EDGE = "POSITIVE",
    parameter PRAGMA_MKFG_DATAPOINT_NAMES = "",
    parameter OUTPUT_DESTINATION_BASE = 0
)(
    input wire clock,
    input wire enable,
    input wire reset,
    input wire [N_CHANNELS-1:0] data_in,
    input wire sync,
    axi_stream.master data_out,
    output wire clock_out,
    output wire [N_CHANNELS-1:0] channel_faults,
    output wire combined_fault,
    axi_lite.slave axi_in
);


    generate
        if(MAIN_DECIMATION_RATIO!=4 && MAIN_DECIMATION_RATIO!=8 && MAIN_DECIMATION_RATIO!=16 && MAIN_DECIMATION_RATIO!=32 && MAIN_DECIMATION_RATIO!=64 && MAIN_DECIMATION_RATIO!=128 && MAIN_DECIMATION_RATIO!=256) begin
            $fatal(1,"INVALID DECIMATION RATIO: The decimation ratio must be one of the following values [4, 8, 16, 32, 64, 128, 256]\n\tCurrent value%d", MAIN_DECIMATION_RATIO);
        end
    endgenerate

    localparam main_clock_selector = $clog2(MAIN_DECIMATION_RATIO)-2;
    localparam comparator_clock_selector = $clog2(COMPARATOR_DECIMATION_RATIO)-2;
    //                                           256 128 64  32  16  8  4
    localparam [7:0] filter_width_map [6:0] = '{ 25, 22, 20, 16, 13, 10, 7 };
    localparam [7:0] output_width_map [6:0] = '{ 16, 16, 16, 14, 12, 8, 6 };
    localparam [7:0] output_shift_map [6:0] = '{ 8,  5,  2,  1,  0, 1, 0};


    /////////////////////////////////////////////////////////////////////
    //                          CONTROL SECTION                        //
    /////////////////////////////////////////////////////////////////////


    parameter N_REGISTERS = 3*N_CHANNELS;

    reg [31:0] cu_write_registers [N_REGISTERS-1:0];
    reg [31:0] cu_read_registers [N_REGISTERS-1:0];
    

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



    wire [31:0] high_tresholds [N_CHANNELS-1:0];
    wire [31:0] low_tresholds [N_CHANNELS-1:0];
    wire [31:0] offsets [N_CHANNELS-1:0];
    
    genvar n;
    generate
        for(n=0; n<N_CHANNELS; n = n+1)begin
            assign low_tresholds[n] = cu_write_registers[n];
            assign high_tresholds[n] = cu_write_registers[N_CHANNELS + n];
            assign offsets[n] = cu_write_registers[2*N_CHANNELS + n];
        end
    endgenerate


    /////////////////////////////////////////////////////////////////////
    //                      CLOCK GENERATION SECTION                   //
    /////////////////////////////////////////////////////////////////////

    localparam [7:0] main_filter_resolution = filter_width_map[main_clock_selector];
    localparam [7:0] main_result_resolution = output_width_map[main_clock_selector];
    localparam [7:0] main_output_shift = output_shift_map[main_clock_selector];


    localparam comparator_enabled = COMPARATOR_DECIMATION_RATIO>0;

    localparam [7:0] comparator_filter_resolution = filter_width_map[comparator_clock_selector];
    localparam [7:0] comparator_result_resolution = output_width_map[comparator_clock_selector];
    localparam [7:0] comparator_output_shift = output_shift_map[comparator_clock_selector];
    
    wire main_sampling_clock, comparator_sampling_clock;



    sigma_delta_clock_generator clk_gen (
        .clock(clock),
        .reset(reset),
        .enable(enable),
        .main_clock_selector(main_clock_selector),
        .comparator_clock_selector(comparator_clock_selector),
        .main_sampling_clock(main_sampling_clock),
        .comparator_sampling_clock(comparator_sampling_clock),
        .sd_clock(clock_out)
    );

    genvar i;



    /////////////////////////////////////////////////////////////////////
    //                            FILTERS SECTION                      //
    /////////////////////////////////////////////////////////////////////

    axi_stream main_data_out[N_CHANNELS]();
    axi_stream comparator_data_out[N_CHANNELS]();

    wire [N_CHANNELS-1:0] high_faults;
    wire [N_CHANNELS-1:0] low_faults;

    generate
        for (i = 0; i<N_CHANNELS; i++) begin
            sigma_delta_channel #(
                .PROCESSING_RESOLUTION(main_filter_resolution),
                .RESULT_RESOLUTION(main_result_resolution),
                .OUTPUT_SHIFT_SIZE(main_output_shift),
                .CHANNEL_INDICATOR(OUTPUT_DESTINATION_BASE + i),
                .SAMPLING_EDGE(SAMPLING_EDGE)
            ) main_channel (
                .clock(clock),
                .reset(reset),
                .sync(sync),
                .offset(offsets[i]),
                .sd_data_in(data_in[i]),
                .sd_clock_in(clock_out),
                .output_clock(main_sampling_clock),
                .data_out(main_data_out[i])
            );
        end
        
    if(comparator_enabled)begin

      
        for (i = 0; i<N_CHANNELS; i++) begin
            sigma_delta_channel #(
                .PROCESSING_RESOLUTION(comparator_filter_resolution),
                .RESULT_RESOLUTION(comparator_result_resolution),
                .OUTPUT_SHIFT_SIZE(comparator_output_shift),
                .CHANNEL_INDICATOR(i),
                .SAMPLING_EDGE(SAMPLING_EDGE)
            ) comparator_channel (
                .clock(clock),
                .reset(reset),
                .sync(1),
                .sd_data_in(data_in[i]),
                .sd_clock_in(clock_out),
                .offset(0),
                .output_clock(comparator_sampling_clock),
                .data_out(comparator_data_out[i])
            );
            
            assign channel_faults[i] = high_faults[i] | low_faults[i];
        end

        
    end

    endgenerate

    
    /////////////////////////////////////////////////////////////////////
    //             COMPARATORS AND OUTPUT SECTION                      //
    /////////////////////////////////////////////////////////////////////


    sigma_delta_comparators #(
        .N_CHANNELS(N_CHANNELS)
    ) fault_comparator (
        .clock(clock),
        .reset(reset),
        .data_in(comparator_data_out),
        .high_tresholds(high_tresholds),
        .low_tresholds(low_tresholds),
        .high_outputs(high_faults),
        .low_outputs(low_faults),
        .combined_output(combined_fault)
    );

    axis_multichannel_combiner #(
        .N_CHANNELS(N_CHANNELS)
    )output_combiner(
        .clock(clock),
        .reset(reset),
        .data_in(main_data_out),
        .data_out(data_out)
    );

endmodule



 /**
    {
        "name": "sigma_delta_processor",
        "type": "parametric_peripheral",
        "registers":[
            {
                "name": "tresh_$_l",
                "n_regs": ["N_CHANNELS"],
                "description": "Lower fault treshold",
                "direction": "RW"
            },
            {
                "name": "tresh_$_h",
                "n_regs": ["N_CHANNELS"],
                "description": "Higher fault treshold",
                "direction": "RW"
            },
            {
                "name": "offset_$",
                "n_regs": ["N_CHANNELS"],
                "description": "Offset Adjustment",
                "direction": "RW"
            }
        ]
    }   
 **/