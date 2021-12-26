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

module AdcProcessing #(parameter BASE_ADDRESS = 'h43c00000, DATA_PATH_WIDTH = 16, DECIMATED = 1, ENABLE_AVERAGE = 0, STICKY_FAULT = 0)(
    input  wire                clock,
    input  wire                reset,
    axi_stream.slave           data_in,
    axi_stream.master           data_out,
    Simplebus.slave simple_bus,
    output reg                 fault
);


    wire [1:0] comparator_address;
    wire [31:0] comparator_threshold;
    wire [1:0] comparator_we;
    wire [2:0] cal_settings_address;
    wire [15:0] cal_settings_data;
    wire cal_we;
    wire gain_enable;
    wire [1:0] latch_mode;
    wire [1:0] clear_latch;
    wire [1:0] trip_high;
    wire [1:0] trip_low;
    wire [7:0] decimation_ratio;
    wire pipeline_flush;
    wire signed [DATA_PATH_WIDTH-1:0] cal_data_in;
    wire cal_in_valid, cal_in_ready;

    AdcProcessingControlUnit #(.BASE_ADDRESS(BASE_ADDRESS), .STICKY_FAULT(STICKY_FAULT)) AdcCU(
        .clock(clock),
        .reset(reset),
        .simple_bus(simple_bus),
        .data_in_valid(data_in.valid),
        // COMPARATORS
        .comparator_address(comparator_address),
        .comparator_threshold(comparator_threshold), 
        .comparator_we(comparator_we),
        .latch_mode(latch_mode),
        .clear_latch(clear_latch),
        .trip_high(trip_high),
        .trip_low(trip_low),
        // CALIBRATION
        .cal_address(cal_settings_address),
        .cal_data(cal_settings_data),
        .cal_we(cal_we),
        .gain_enable(gain_enable),
        .pipeline_flush(pipeline_flush),
        .fault(fault),
        .decimation_ratio(decimation_ratio)
    );

   defparam fast_cmp.DATA_PATH_WIDTH = DATA_PATH_WIDTH;
    comparator fast_cmp(
        .clock(clock),
        .reset(reset),
        .threshold_address(comparator_address),
        .threshold_in(comparator_threshold[15:0]),
        .threshold_write_enable(comparator_we[0]),
        .data_in(data_in.data),
        .latching_mode(latch_mode[0]),
        .clear_latch(clear_latch[0]),
        .trip_high(trip_high[0]),
        .trip_low(trip_low[0])
    );

    generate
        if(DECIMATED==0)begin
            assign cal_data_in = data_in.data;
            assign cal_in_valid = data_in.valid;
            assign data_in.ready = cal_in_ready;
        end else if(DECIMATED==1)begin

            axi_stream decimated_data();        
            assign cal_data_in = decimated_data.data;
            assign cal_in_valid = decimated_data.valid;
            assign decimated_data.ready = cal_in_ready;
            
            defparam dec.MAX_DECIMATION_RATIO = 16;
            defparam dec.DATA_WIDTH = DATA_PATH_WIDTH;
            defparam dec.AVERAGING = ENABLE_AVERAGE;           
            standard_decimator dec(
                .clock(clock),
                .reset(reset),
                .data_in(data_in),
                .data_out(decimated_data),
                .decimation_ratio(decimation_ratio)
            );

        end else begin
            defparam dec.DATA_PATH_WIDTH = 32;
            Decimator_wrapper dec(
                .clock(clock),
                .data_in_tdata(data_in.data),
                .data_in_tvalid(data_in.valid),
                .data_in_tready(data_in.ready),
                .data_out_tdata(cal_data_in),
                .data_out_tvalid(cal_in_valid),
                .data_out_tready(cal_in_ready)
            );
        end
    endgenerate


    defparam slow_cmp.DATA_PATH_WIDTH = DATA_PATH_WIDTH;
    comparator slow_cmp(
        .clock(clock),
        .reset(reset),
        .threshold_address(comparator_address),
        .threshold_in(comparator_threshold[31:16]),
        .threshold_write_enable(comparator_we[1]),
        .data_in(cal_data_in),
        .latching_mode(latch_mode[1]),
        .clear_latch(clear_latch[1]),
        .trip_high(trip_high[1]),
        .trip_low(trip_low[1])
    );


    defparam calibrator.DATA_PATH_WIDTH = DATA_PATH_WIDTH;
    calibration calibrator(
        .clock(clock),
        .reset(reset),
        .in_valid(cal_in_valid),
        .in_ready(cal_in_ready),
        .pipeline_flush(pipeline_flush),
        .cal_address(cal_settings_address),
        .cal_data(cal_settings_data),
        .cal_we(cal_we),
        .data_in(cal_data_in),
        .gain_enable(gain_enable),
        .data_out(data_out.data),
        .out_ready(data_out.ready),
        .out_valid(data_out.valid)
    );

endmodule