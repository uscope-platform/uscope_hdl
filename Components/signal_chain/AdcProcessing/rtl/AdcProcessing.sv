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

module AdcProcessing #(
    parameter DATA_PATH_WIDTH = 16,
    parameter DEST_WIDTH = 8,
    parameter USER_WIDTH = 16,
    DATA_BLOCK_BASE_ADDR = 0,
    FAST_DATA_OFFSET = 0,
    FLTER_TAP_WIDTH = 16,
    DECIMATED = 1,
    DENOISING = 0,
    ENABLE_AVERAGE = 0,
    STICKY_FAULT = 0,
    N_CHANNELS = 4,
    MAX_FILTER_TAPS = 256,
    parameter [N_CHANNELS-1:0] OUTPUT_SIGNED = {N_CHANNELS{1'b1}},
    FILTER_WORKING_WIDTH = DATA_PATH_WIDTH > FLTER_TAP_WIDTH ? DATA_PATH_WIDTH : FLTER_TAP_WIDTH,
    parameter [FLTER_TAP_WIDTH-1:0] FILTER_TAPS [MAX_FILTER_TAPS:0] = '{MAX_FILTER_TAPS+1{0}},
    LINEARIZER_SEGMENTS = 4,
    parameter [DATA_PATH_WIDTH-1:0] LINEARIZER_BOUNDS [N_CHANNELS-1:0][LINEARIZER_SEGMENTS-1:0] = '{default:0},
    parameter [DATA_PATH_WIDTH:0] LINEARIZER_GAINS [N_CHANNELS-1:0][LINEARIZER_SEGMENTS-1:0] = '{default:0},
    PRAGMA_MKFG_MODULE_TOP = "AdcProcessing",
    parameter PRAGMA_MKFG_DATAPOINT_NAMES = "" 
)(
    input  wire       clock,
    input  wire       reset,
    axi_stream.slave  data_in,
    axi_stream.master filtered_data_out,
    axi_stream.master fast_data_out,
    axi_lite.slave    axi_in,
    output reg        fault
);


    initial begin
        $display("--------------------------------------------------------------");
        $display("%s", PRAGMA_MKFG_DATAPOINT_NAMES);
        $display("--------------------------------------------------------------");
    end

    adc_processing_types::comparator_control_signal trip_high;
    adc_processing_types::comparator_control_signal trip_low;


    wire taps_we;


    typedef struct {
        adc_processing_types::comparators comparator_tresholds;
        adc_processing_types::calibrator_coefficients calibration[N_CHANNELS];
        adc_processing_types::denoise_tresholds denoise_tresholds[N_CHANNELS];
        adc_processing_types::control_register control;
        reg [31:0] tap_data;
        reg [31:0] tap_address;
    } adc_processing_registers;

    adc_processing_registers registers;

    axil_simple_register_cu #(
        .READ_TYPE(adc_processing_registers),
        .WRITE_TYPE(adc_processing_registers),
        .INITIAL_OUTPUT_VALUES('{ 
            comparator_tresholds:'{
                slow: '{
                    low_falling: -16'sd32768, 
                    low_rising:  -16'sd32768,
                    high_falling: 16'sd32767,
                    high_rising:  16'sd32767
                },
                fast: '{
                    low_falling: -16'sd32768, 
                    low_rising:  -16'sd32768,
                    high_falling: 16'sd32767,
                    high_rising:  16'sd32767
                }
            },
            default: 0
        }),
        .ADDRESS_MASK('hff),
        .TRIGGER_MASK('{tap_address: 1, default: 0})
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(registers),
        .output_registers(registers),
        .trigger_out(taps_we),
        .axil(axi_in)
    );


    processing_fault_collector #(
        .STICKY_FAULT(STICKY_FAULT)
    ) fault_collector(
        .clock(clock),
        .reset(reset),
        .data_in_valid(data_in.valid),
        .clear_fault(registers.control.clear_fault),
        .disable_fault(registers.control.disable_fault),
        .slow_fault_threshold(registers.control.slow_fault_threshold),
        .trip_high(trip_high),
        .trip_low(trip_low),
        .fault(fault)
    );

    comparator #(
        .DATA_PATH_WIDTH(DATA_PATH_WIDTH)
    )fast_cmp(
        .clock(clock),
        .reset(reset),
        .tresholds(registers.comparator_tresholds.fast),
        .data_in(data_in),
        .latching_mode(registers.control.latch_mode.fast),
        .clear_latch(registers.control.clear_latch.fast),
        .trip_high(trip_high.fast),
        .trip_low(trip_low.fast)
    );

    axi_stream #(
        .DATA_WIDTH(DATA_PATH_WIDTH)
    ) cal_out();

    calibration #(
        .DATA_PATH_WIDTH(DATA_PATH_WIDTH),
        .N_CHANNELS(N_CHANNELS),
        .DATA_BLOCK_BASE_ADDR(DATA_BLOCK_BASE_ADDR),
        .OUTPUT_SIGNED(OUTPUT_SIGNED)
    ) calibrator(
        .clock(clock),
        .reset(reset),
        .data_in(data_in),
        .coefficients(registers.calibration),
        .shift_enable(registers.control.shift_enable),
        .data_out(cal_out)
    );

    axi_stream #(
        .DATA_WIDTH(DATA_PATH_WIDTH)
    ) denoise_out();

    denoiser #(
        .DATA_PATH_WIDTH(DATA_PATH_WIDTH),
        .DATA_BLOCK_BASE_ADDR(DATA_BLOCK_BASE_ADDR),
        .N_CHANNELS(N_CHANNELS)
    )denoise(
        .clock(clock),
        .reset(reset),
        .denoise_tresholds(registers.denoise_tresholds),
        .enable(DENOISING),
        .data_in(cal_out),
        .data_out(denoise_out)
    );

    axi_stream #(
        .DATA_WIDTH(DATA_PATH_WIDTH)
    ) lin_out();

    linearizer #(
        .DATA_PATH_WIDTH(DATA_PATH_WIDTH),
        .DATA_BLOCK_BASE_ADDR(DATA_BLOCK_BASE_ADDR),
        .N_CHANNELS(N_CHANNELS),
        .DEST_WIDTH(DEST_WIDTH),
        .USER_WIDTH(USER_WIDTH),
        .N_SEGMENTS(LINEARIZER_SEGMENTS),
        .BOUNDS(LINEARIZER_BOUNDS),
        .GAINS(LINEARIZER_GAINS)
    )linearizer(
        .clock(clock),
        .reset(reset),
        .enable(registers.control.linearizer_enable),
        .data_in(denoise_out),
        .data_out(lin_out)
    );

    assign fast_data_out.data = lin_out.data;
    assign fast_data_out.user = lin_out.user;
    assign fast_data_out.valid = lin_out.valid;
    assign fast_data_out.dest = lin_out.dest + FAST_DATA_OFFSET;
    
    generate
        if(DECIMATED==0)begin
            assign filtered_data_out.data = lin_out.data;
            assign filtered_data_out.valid = lin_out.valid;
            assign filtered_data_out.user = lin_out.user;
            assign filtered_data_out.dest = lin_out.dest;
            assign lin_out.ready = filtered_data_out.ready;

        end else if(DECIMATED==1)begin
            
            standard_decimator #(
                .MAX_DECIMATION_RATIO(16),
                .DATA_WIDTH(DATA_PATH_WIDTH),
                .AVERAGING(ENABLE_AVERAGE),
                .N_CHANNELS(N_CHANNELS)
            ) dec(
                .clock(clock),
                .reset(reset),
                .data_in(lin_out),
                .data_out(filtered_data_out),
                .decimation_ratio(registers.control.decimation_ratio)
            );

        end else if(DECIMATED == 2)begin


        axi_stream #(
            .DATA_WIDTH(DATA_PATH_WIDTH)
        ) raw_filtered_out();

        fir_filter_serial #(
            .DATA_PATH_WIDTH(DATA_PATH_WIDTH),
            .TAP_WIDTH(FLTER_TAP_WIDTH),
            .MAX_N_TAPS(MAX_FILTER_TAPS),
            .TAPS_IV(FILTER_TAPS)
        )filter(
            .clock(clock),
            .reset(reset),
            .n_taps(registers.control.n_taps),
            .tap_data(registers.tap_data),
            .tap_addr(registers.tap_address),
            .tap_write(taps_we),
            .data_in(lin_out),
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
            .decimation_ratio(registers.control.decimation_ratio)
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
        .tresholds(registers.comparator_tresholds.slow),
        .data_in(slow_cmp_in),
        .latching_mode(registers.control.latch_mode.slow),
        .clear_latch(registers.control.clear_latch.slow),
        .trip_high(trip_high.slow),
        .trip_low(trip_low.slow)
    );


endmodule



 /**
    {
        "name": "AdcProcessing",
        "type": "parametric_peripheral",
        "registers":[
            {
                "name": "cmp_slow_low",
                "n_regs": ["1"],
                "description": "Slow comparator low band thresholds",
                "direction": "RW",
                "fields":[
                    {
                        "name":"rising",
                        "description": "Low band release treshold (rising edge in normal mode)",
                        "start_position": 0,
                        "n_fields":["1"],
                        "length": 16
                    },
                    {
                        "name":"falling",
                        "description": "Low band enter treshold (falling edge in normal mode)",
                        "start_position": 16,
                        "n_fields":["1"],
                        "length": 16
                    }
                ]
            },
            {
                "name": "cmp_slow_high",
                "n_regs": ["1"],
                "description": "Slow comparator high band thresholds",
                "direction": "RW",
                "fields":[
                    {
                        "name":"rising",
                        "description": "High band enter treshold (rising edge in normal mode)",
                        "start_position": 0,
                        "n_fields":["1"],
                        "length": 16
                    },
                    {
                        "name":"falling",
                        "description": "High band release treshold (falling edge in normal mode)",
                        "start_position": 16,
                        "n_fields":["1"],
                        "length": 16
                    }
                ]
            },
            {
                "name": "cmp_fast_low",
                "n_regs": ["1"],
                "description": "Fast comparator low band thresholds",
                "direction": "RW",
                "fields":[
                    {
                        "name":"rising",
                        "description": "Low band release treshold (rising edge in normal mode)",
                        "start_position": 0,
                        "n_fields":["1"],
                        "length": 16
                    },
                    {
                        "name":"falling",
                        "description": "Low band enter treshold (falling edge in normal mode)",
                        "start_position": 16,
                        "n_fields":["1"],
                        "length": 16
                    }
                ]
            },
            {
                "name": "cmp_fast_high",
                "n_regs": ["1"],
                "description": "Fast comparator high band thresholds",
                "direction": "RW",
                "fields":[
                    {
                        "name":"rising",
                        "description": "High band enter treshold (rising edge in normal mode)",
                        "start_position": 0,
                        "n_fields":["1"],
                        "length": 16
                    },
                    {
                        "name":"falling",
                        "description": "High band release treshold (falling edge in normal mode)",
                        "start_position": 16,
                        "n_fields":["1"],
                        "length": 16
                    }
                ]
            },
            {
                "name": "calibration_$",
                "n_regs": ["N_CHANNELS"],
                "description": "Per-channel calibration coefficients (signed offset and data shift)",
                "direction": "RW",
                "fields":[
                    {
                        "name":"shift",
                        "description": "Per-channel data shift amount",
                        "start_position": 28,
                        "n_fields":["1"],
                        "length": 4
                    },
                    {
                        "name":"offset",
                        "description": "Signed per-channel offset calibration coefficient",
                        "start_position": 0,
                        "n_fields":["1"],
                        "length": 28
                    }
                ]
            },
            {
                "name": "denoise_tresh_$",
                "n_regs": ["N_CHANNELS"],
                "description": "denoiser tresholds",
                "direction": "RW",
                "fields":[
                     {
                        "name":"positive",
                        "description": "Positive difference limit",
                        "start_position": 0,
                        "n_fields":["1"],
                        "length": 16
                    },
                    {
                        "name":"negative",
                        "description": "Negative difference limit",
                        "start_position": 16,
                        "n_fields":["1"],
                        "length": 16
                    }
                ]
            },
            {
                "name": "control",
                "n_regs": ["1"],
                "description": "ADC post processing module control register",
                "direction": "RW",
                "fields":[
                    {
                        "name":"shift_enable",
                        "description": "Enables calibration shifter",
                        "start_position": 0,
                        "n_fields":["1"],
                        "length": 1
                    },
                    {
                        "name":"latch_mode",
                        "description": "Toggles comparators between normal and latching mode",
                        "start_position": 1,
                        "n_fields":["1"],
                        "length": 2
                    },
                    {
                        "name":"clear_latch",
                        "description": "Clear comparators latch when in latching mode",
                        "start_position": 3,
                        "n_fields":["1"],
                        "length": 2
                    },
                    {
                        "name":"clear_fault",
                        "description": "Clear sticky fault satus",
                        "start_position": 5,
                        "n_fields":["1"],
                        "length": 1
                    },
                    {
                        "name":"fault_disable",
                        "description": "Disable fault generation",
                        "start_position": 6,
                        "n_fields":["1"],
                        "length": 1
                    },
                    {
                        "name":"linearizer_enable",
                        "description": "Enable data linearization",
                        "start_position": 7,
                        "n_fields":["1"],
                        "length": 1
                    },
                    {
                        "name":"fault_delay",
                        "description": "Amount of clock cycles a slow comparator must be active before triggering a fault",
                        "start_position": 8,
                        "n_fields":["1"],
                        "length": 8
                    },
                    {
                        "name":"n_taps",
                        "description": "Number of active FIR filter taps",
                        "start_position": 16,
                        "n_fields":["1"],
                        "length": 8
                    },
                    {
                        "name":"decimation",
                        "description": "Decimation ratio between input and output data",
                        "start_position": 24,
                        "n_fields":["1"],
                        "length": 8
                    }
                ]
            },
            {
                "name": "filter_tap_data",
                "n_regs": ["1"],
                "description": "Fir Filter tap data value",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "filter_tap_address",
                "n_regs": ["1"],
                "description": "Fir Filter tap address value",
                "direction": "RW",
                "fields":[]
            }
        ]
    }   
 **/