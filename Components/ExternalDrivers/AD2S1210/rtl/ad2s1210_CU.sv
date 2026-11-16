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

module ad2s1210_cu (
    input wire clock,
    input wire reset,
    input wire read_angle,
    input wire read_speed,
    axi_stream.master external_spi_transfer,
    input wire [31:0] SPI_data_in,
    output reg [1:0] mode,
    output reg [1:0] resolution,
    output wire sample,
    output reg rdc_reset,
    output reg [4:0] spi_transfer_length,
    axi_stream.master data_out,
    axi_lite.slave axi_in
);

    reg fc_mode;

    reg read_sample, fault_clear_sample;

 
    reg [1:0] internal_mode;

    reg [7:0] AD2S1210_addr[0:14] = '{'h80,'h81,'h82,'h83,'h88,'h89,'h8A,'h8B,'h8C,'h8D,'h8E,'h91,'h92,'hf0,'hff};
    reg [7:0] AD2S1210_values[0:14];

    reg [7:0] sample_read_delay;
    reg [7:0] sample_pulse_length;

    wire configuration_done, start_configuration;
    assign start_configuration = trigger_out & ~trigger_type;

    wire start_fault_clear, fault_clear_done;
    assign start_fault_clear = trigger_out & trigger_type;
    

    assign mode = state==configure_state | fc_mode ? 2'b11 : internal_mode;
    assign sample = read_sample & fault_clear_sample;



    enum logic [1:0] {
        run_state =             2'b00,
        configure_state =      2'b01,
        fault_clear_state =      2'b11
    } state = run_state;



    always_ff @(posedge clock) begin
        case (state)
            run_state: begin
                if(start_configuration)
                    state <= configure_state;
                else if(start_fault_clear)
                    state <= fault_clear_state;
            end
            configure_state:begin
                if(configuration_done)
                    state <= run_state;
            end
            fault_clear_state:begin
                if(fault_clear_done)
                    state <= run_state;
            end
            default: 
                state <= run_state;
        endcase
    end



    reg clear_fault;
    reg trigger_out;
    reg trigger_type;

    reg [7:0] slow_fault_threshold;

    typedef struct packed {
        logic [2:0] rsvd_1;              // [31:29]
        logic [4:0] spi_transfer_length; // [28:24]
        logic [7:0] sample_read_delay;   // [23:16]
        logic [7:0] sample_pulse_length; // [15:8]
        logic [2:0] rsvd_2;              // [7:5]
        logic       rdc_reset;           // [4]
        logic [1:0] resolution;          // [3:2]
        logic [1:0] rsvd_3;              // [1:0]
    } ad2s1210_control_fields;

    typedef struct {
        reg [31:0] rdc_los_thres;
        reg [31:0] rdc_dos_or_thres;
        reg [31:0] rdc_dos_mism_thres;
        reg [31:0] rdc_dos_reset_minmax;
        reg [31:0] rdc_lot_high;
        reg [31:0] rdc_lot_low;
        reg [31:0] rdc_exc_freq;
        reg [31:0] rdc_control;
        reg [31:0] rdc_reset;
        reg [31:0] trigger;
        ad2s1210_control_fields control;
    } ad2s1210_cu_registers;

    ad2s1210_cu_registers write_registers, read_registers;

    axil_simple_register_cu #(
        .READ_TYPE(ad2s1210_cu_registers),
        .WRITE_TYPE(ad2s1210_cu_registers),
        .INITIAL_OUTPUT_VALUES('{control: '{spi_transfer_length: 5'd22, resolution: 2'b10, default: 0}, default: 0}),
        .ADDRESS_MASK('h3f),
        .TRIGGER_MASK('{trigger: 1, default: 0})
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(read_registers),
        .output_registers(write_registers),
        .trigger_out(trigger_out),
        .axil(axi_in)
    );

    assign AD2S1210_values[0:3] = '{4{32'b0}};
    assign AD2S1210_values[4] = write_registers.rdc_los_thres;
    assign AD2S1210_values[5] = write_registers.rdc_dos_or_thres;
    assign AD2S1210_values[6] = write_registers.rdc_dos_mism_thres;
    assign AD2S1210_values[7] = write_registers.rdc_dos_reset_minmax;
    assign AD2S1210_values[8] = write_registers.rdc_lot_high;
    assign AD2S1210_values[9] = write_registers.rdc_lot_low;
    assign AD2S1210_values[10] = write_registers.rdc_exc_freq;
    assign AD2S1210_values[11] = write_registers.rdc_control;
    assign AD2S1210_values[12] = write_registers.rdc_reset;
    assign AD2S1210_values[13:14] = '{2{32'b0}};

    assign trigger_type = write_registers.trigger[0];

    assign resolution          = write_registers.control.resolution;
    assign rdc_reset           = write_registers.control.rdc_reset;
    assign sample_pulse_length = write_registers.control.sample_pulse_length;
    assign sample_read_delay   = write_registers.control.sample_read_delay;
    assign spi_transfer_length = write_registers.control.spi_transfer_length;

    always_comb begin
        read_registers = write_registers;
        read_registers.trigger = 0;
        read_registers.control = '{
            spi_transfer_length: spi_transfer_length,
            sample_read_delay:   sample_read_delay,
            sample_pulse_length: sample_pulse_length,
            rdc_reset:           rdc_reset,
            resolution:          resolution,
            default: 0
        };
    end

    axi_stream read_spi();
    axi_stream cfg_spi();
    axi_stream fc_spi();


    axi_stream_combiner_3 #(
        .INPUT_DATA_WIDTH(32),
        .OUTPUT_DATA_WIDTH(32),
        .MSB_DEST_SUPPORT("FALSE")
    ) spi_stream_combiner (
        .clock(clock),
        .reset(reset),
        .stream_in_1(read_spi),
        .stream_in_2(cfg_spi),
        .stream_in_3(fc_spi),
        .stream_out(external_spi_transfer)
    );



    ad2s1210_reader reader (
        .clock(clock),
        .reset(reset),
        .start(read_angle | read_speed),
        .transfer_type(read_speed),
        .sample_length(sample_pulse_length),
        .sample_delay(sample_read_delay),
        .spi_data_in(SPI_data_in),
        .spi_transfer(read_spi),
        .sample(read_sample),
        .mode(internal_mode),
        .data_out(data_out)
    );


    ad2s1210_configurator configurator (
        .clock(clock),
        .reset(reset),
        .start(start_configuration),
        .config_address(AD2S1210_addr),
        .config_data(AD2S1210_values),
        .spi_transfer(cfg_spi),
        .done(configuration_done)
    );


    ad2s1210_fault_handler fault_handler (
        .clock(clock),
        .reset(reset),
        .start(start_fault_clear),
        .sample_delay(sample_read_delay),
        .sample_length(sample_pulse_length),
        .spi_transfer(fc_spi),
        .mode(fc_mode),
        .sample(fault_clear_sample), 
        .done(fault_clear_done)
    );




endmodule


/**
       {
        "name": "ad2s1210_cu",
        "type": "parametric_peripheral",
        "registers":[
            {
                "name": "rdc_los_thres",
                "n_regs": ["1"],
                "description": "Value of AD2S1210 Loss of signal threshold register",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "rdc_dos_or_thres",
                "n_regs": ["1"],
                "description": "Value of AD2S1210 Degradation of signal overrange threshold register",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "rdc_dos_mism_thres",
                "n_regs": ["1"],
                "description": "Value of AD2S1210 Degradation of signal mismatch threshold register",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "rdc_dos_reset_minmax",
                "n_regs": ["1"],
                "description": "Value of AD2S1210 Degradation of signal minimum and maximum reset threshold register",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "rdc_lot_high",
                "n_regs": ["1"],
                "description": "Value of AD2S1210 Loss of tracking high threshold register",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "rdc_lot_low",
                "n_regs": ["1"],
                "description": "Value of AD2S1210 Loss of tracking low threshold register",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "rdc_exc_freq",
                "n_regs": ["1"],
                "description": "Value of AD2S1210 excitation frequency register",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "rdc_control",
                "n_regs": ["1"],
                "description": "Value of AD2S1210 control register",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "rdc_reset",
                "n_regs": ["1"],
                "description": "Value of AD2S1210 soft reset register",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "trigger",
                "n_regs": ["1"],
                "description": "Writing 0 to this register will configure the RDC while writing 1 will clear pending",
                "direction": "W",
                "fields":[]
            },
            {
                "name": "control",
                "n_regs": ["1"],
                "description": "AD2S1210 Driver control register",
                "direction": "RW",
                "fields":[
                    {
                        "name":"resolution",
                        "description": "Resolver to digital resolution setting",
                        "n_fields":["1"],
                        "start_position": 2,
                        "length": 2
                    },
                    {
                        "name":"rdc_reset",
                        "description": "Value of the AD2S1210 RESET pin",
                        "n_fields":["1"],
                        "start_position": 4,
                        "length": 1
                    },
                    {
                        "name":"sample_pulse_length",
                        "description": "length of the sample pulse",
                        "n_fields":["1"],   
                        "start_position": 8,
                        "length": 8
                    },
                    {
                        "name":"sample_read_delay",
                        "description": "delay between the sample pulse and the data readback phase",
                        "n_fields":["1"],   
                        "start_position": 16,
                        "length": 8
                    },
                    {
                        "name":"spi_transfer_length",
                        "description": "lenght of the SPI transfer",
                        "n_fields":["1"],   
                        "start_position": 24,
                        "length": 5
                    }
                ]     
            }
        ]
    }  
    **/