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

module AdcProcessing #(
    parameter DATA_PATH_WIDTH = 16,
    FLTER_TAP_WIDTH = 16,
    DECIMATED = 1,
    ENABLE_AVERAGE = 0,
    AVERAGING_DIVISOR = 2,
    STICKY_FAULT = 0,
    parameter N_CHANNELS = 4,
    parameter [N_CHANNELS-1:0] OUTPUT_SIGNED = {N_CHANNELS{1'b1}}
)(
    input  wire       clock,
    input  wire       reset,
    axi_stream.slave  data_in,
    axi_stream.master filtered_data_out,
    axi_stream.master fast_data_out,
    axi_lite.slave    axi_in,
    output reg        fault
);

    wire shift_enable;
    wire [1:0] latch_mode;
    wire [1:0] clear_latch;
    wire [1:0] trip_high;
    wire [1:0] trip_low;
    wire [7:0] decimation_ratio;


    wire signed [DATA_PATH_WIDTH-1:0] comparator_thresholds [0:7];

    wire signed [DATA_PATH_WIDTH-1:0] offset [N_CHANNELS-1:0];
    wire [DATA_PATH_WIDTH-1:0] shift [N_CHANNELS-1:0];

    wire [7:0] n_taps;
    wire [FLTER_TAP_WIDTH-1:0] taps_data;
    wire [7:0] taps_addr;
    wire taps_we;

    AdcProcessingControlUnit #(
        .STICKY_FAULT(STICKY_FAULT),
        .FLTER_TAP_WIDTH(FLTER_TAP_WIDTH),
        .DATA_PATH_WIDTH(DATA_PATH_WIDTH),
        .N_CHANNELS(N_CHANNELS)
    ) AdcCU(
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
        .shift(shift),
        .offset(offset),
        .shift_enable(shift_enable),
        .fault(fault),
        // FILTERING AND DECIMATION
        .decimation_ratio(decimation_ratio),
        .n_taps(n_taps),
        .taps_data(taps_data),
        .taps_addr(taps_addr),
        .taps_we(taps_we)
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

    axi_stream #(
        .DATA_WIDTH(DATA_PATH_WIDTH)
    ) cal_out();

    calibration #(
        .DATA_PATH_WIDTH(DATA_PATH_WIDTH),
        .N_CHANNELS(N_CHANNELS),
        .OUTPUT_SIGNED(OUTPUT_SIGNED)
    ) calibrator(
        .clock(clock),
        .reset(reset),
        .data_in(data_in),
        .shift(shift),
        .offset(offset),
        .shift_enable(shift_enable),
        .data_out(cal_out)
    );


    assign fast_data_out.data = cal_out.data;
    assign fast_data_out.valid = cal_out.valid;
    assign fast_data_out.dest = cal_out.dest;

    generate
        if(DECIMATED==0)begin
            assign filtered_data_out.data = fast_data_out.data;
            assign filtered_data_out.valid = fast_data_out.valid;
            assign filtered_data_out.dest = fast_data_out.dest;
            assign fast_data_out.ready = filtered_data_out.ready;

        end else if(DECIMATED==1)begin
            
            standard_decimator #(
                .MAX_DECIMATION_RATIO(16),
                .DATA_WIDTH(DATA_PATH_WIDTH),
                .AVERAGING(ENABLE_AVERAGE),
                .AVERAGING_DIVISOR(AVERAGING_DIVISOR),
                .N_CHANNELS(N_CHANNELS)
            ) dec(
                .clock(clock),
                .reset(reset),
                .data_in(cal_out),
                .data_out(filtered_data_out),
                .decimation_ratio(decimation_ratio)
            );

        end else if(DECIMATED == 2)begin


        axi_stream #(
            .DATA_WIDTH(DATA_PATH_WIDTH)
        ) raw_filtered_out();

        fir_filter_serial #(
            .DATA_PATH_WIDTH(DATA_PATH_WIDTH),
            .TAP_WIDTH(FLTER_TAP_WIDTH),
            .MAX_N_TAPS(256)
        )filter(
            .clock(clock),
            .reset(reset),
            .n_taps(n_taps),
            .tap_data(taps_data),
            .tap_addr(taps_addr),
            .tap_write(taps_we),
            .data_in(cal_out),
            .data_out(raw_filtered_out)
        );

        standard_decimator #(
            .MAX_DECIMATION_RATIO(16),
            .DATA_WIDTH(DATA_PATH_WIDTH),
            .AVERAGING(0),
            .N_CHANNELS(N_CHANNELS)
        ) dec(
            .clock(clock),
            .reset(reset),
            .data_in(raw_filtered_out),
            .data_out(filtered_data_out),
            .decimation_ratio(decimation_ratio)
        );
        end
    endgenerate

    axi_stream #(
        .DATA_WIDTH(DATA_PATH_WIDTH)
    ) slow_cmp_in();

    assign slow_cmp_in.data = filtered_data_out.data;
    assign slow_cmp_in.valid = filtered_data_out.valid;
    assign slow_cmp_in.dest = filtered_data_out.dest;

    comparator #(
        .DATA_PATH_WIDTH(DATA_PATH_WIDTH)
    ) slow_cmp(
        .clock(clock),
        .reset(reset),
        .thresholds(comparator_thresholds[4:7]),
        .data_in(slow_cmp_in),
        .latching_mode(latch_mode[1]),
        .clear_latch(clear_latch[1]),
        .trip_high(trip_high[1]),
        .trip_low(trip_low[1])
    );


endmodule


 /**
       {
        "name": "AdcProcessing",
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
                        "name":"cal_shift",
                        "description": "Ammount of bits the data will be shifted right by (gain)",
                        "start_position": 5,
                        "length": 3
                    },
                    {
                        "name":"fault_delay",
                        "description": "Amount of clock cycles a slow comparator must be active before triggering a fault",
                        "start_position": 8,
                        "length": 8
                    },
                    {
                        "name":"clear_fault",
                        "description": "Clear sticky fault satus",
                        "start_position": 16,
                        "length": 1
                    },
                    {
                        "name":"fault_disable",
                        "description": "Disable fault generation",
                        "start_position": 17,
                        "length": 1
                    },
                    {
                        "name":"decimation",
                        "description": "Decimation ratio between input and output data",
                        "start_position": 24,
                        "length": 8
                    }
                ]
            }
        ]
    }  
    **/