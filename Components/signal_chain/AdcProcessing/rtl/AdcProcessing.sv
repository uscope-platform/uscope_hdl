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
    input  wire       clock,
    input  wire       reset,
    axi_stream.slave  data_in,
    axi_stream.master data_out,
    axi_lite.slave    axi_in,
    output reg        fault
);

    wire gain_enable;
    wire [1:0] latch_mode;
    wire [1:0] clear_latch;
    wire [1:0] trip_high;
    wire [1:0] trip_low;
    wire [7:0] decimation_ratio;
    wire pipeline_flush;


    wire signed [DATA_PATH_WIDTH-1:0] cal_coefficients [2:0];
    wire signed [DATA_PATH_WIDTH-1:0] comparator_thresholds [0:7];

    axi_stream #(
        .DATA_WIDTH(DATA_PATH_WIDTH)
    ) cal_in();

    AdcProcessingControlUnit #(.BASE_ADDRESS(BASE_ADDRESS), .STICKY_FAULT(STICKY_FAULT), .DATA_PATH_WIDTH(DATA_PATH_WIDTH)) AdcCU(
        .clock(clock),
        .reset(reset),
        .axi_in(axi_in),
        .data_in_valid(data_in.valid),
        // COMPARATORS
        .comparator_thresholds(comparator_thresholds),
        .latch_mode(latch_mode),
        .clear_latch(clear_latch),
        .trip_high(trip_high),
        .trip_low(trip_low),
        // CALIBRATION
        .calibrator_coefficients(cal_coefficients),
        .gain_enable(gain_enable),
        .pipeline_flush(pipeline_flush),
        .fault(fault),
        .decimation_ratio(decimation_ratio)
    );

    comparator #(
        .DATA_PATH_WIDTH(DATA_PATH_WIDTH)
    )fast_cmp(
        .clock(clock),
        .reset(reset),
        .thresholds(comparator_thresholds[0:3]),
        .data_in(data_in),
        .latching_mode(latch_mode[0]),
        .clear_latch(clear_latch[0]),
        .trip_high(trip_high[0]),
        .trip_low(trip_low[0])
    );

    generate
        if(DECIMATED==0)begin
            assign cal_in.data = data_in.data;
            assign cal_in.valid = data_in.valid;
            assign data_in.ready = cal_in.ready;

        end else if(DECIMATED==1)begin
            
         
            standard_decimator #(
                .MAX_DECIMATION_RATIO(16),
                .DATA_WIDTH(DATA_PATH_WIDTH),
                .AVERAGING(ENABLE_AVERAGE)
            ) dec(
                .clock(clock),
                .reset(reset),
                .data_in(data_in),
                .data_out(cal_in),
                .decimation_ratio(decimation_ratio)
            );

        end else begin
            Decimator_wrapper #(
                .DATA_PATH_WIDTH(32)
            ) dec(
                .clock(clock),
                .data_in_tdata(data_in.data),
                .data_in_tvalid(data_in.valid),
                .data_in_tready(data_in.ready),
                .data_out_tdata(cal_in.data),
                .data_out_tvalid(cal_in.valid),
                .data_out_tready(cal_in.ready)
            );
        end
    endgenerate


    comparator #(
        .DATA_PATH_WIDTH(DATA_PATH_WIDTH)
    ) slow_cmp(
        .clock(clock),
        .reset(reset),
        .thresholds(comparator_thresholds[4:7]),
        .data_in(cal_in),
        .latching_mode(latch_mode[1]),
        .clear_latch(clear_latch[1]),
        .trip_high(trip_high[1]),
        .trip_low(trip_low[1])
    );


    calibration #(
        .DATA_PATH_WIDTH(DATA_PATH_WIDTH)
    ) calibrator(
        .clock(clock),
        .reset(reset),
        .data_in(cal_in),
        .pipeline_flush(pipeline_flush),
        .calibrator_coefficients(cal_coefficients),
        .gain_enable(gain_enable),
        .data_out(data_out)
    );

endmodule