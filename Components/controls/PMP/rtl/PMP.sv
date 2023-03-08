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

`timescale 10 ns / 1 ns
`include "interfaces.svh"

module pre_modulation_processor #(
    CONVERTER_SELECTION = "DYNAMIC",
    PWM_BASE_ADDR = 0,
    N_PWM_CHANNELS = 4,
    N_CHAINS = 2
)(
    input wire clock,
    input wire reset,
    axi_lite.slave axi_in,
    axi_lite.master axi_out
);

    reg [31:0] cu_write_registers [13:0];
    reg [31:0] cu_read_registers [13:0];

    reg config_required;
    wire [4:0] triggers;

    localparam [31:0] TRIGGER_REGISTERS_IDX [4:0] = '{2, 3, 4, 5, 0};
    wire modulation_status;

    axil_simple_register_cu #(
        .N_READ_REGISTERS(14),
        .N_WRITE_REGISTERS(14),
        .REGISTERS_WIDTH(32),
        .ADDRESS_MASK('h3f),
        .N_TRIGGER_REGISTERS(5),
        .TRIGGER_REGISTERS_IDX(TRIGGER_REGISTERS_IDX)
    ) CU (
        .clock(clock),
        .reset(reset | ~config_required),
        .input_registers(cu_read_registers),
        .output_registers(cu_write_registers),
        .trigger_out(triggers),
        .axil(axi_in)
    );

    reg modulator_stop_request;
    reg modulator_start_request;
    reg [1:0] modulation_type;
    reg [1:0] converter_type;
    reg [31:0] period;
    
    reg [15:0] modulation_parameters [11:0];

    assign {modulator_stop_request, modulator_start_request,  converter_type, modulation_type} = cu_write_registers[0];
    assign period = cu_write_registers[1];
    
    genvar i;
    for(i = 0; i<12; i++)begin
        assign modulation_parameters[i] = cu_write_registers[i+2];
    end
    

    assign cu_read_registers[0] = {modulator_stop_request, modulator_start_request, converter_type, modulation_type};
    assign cu_read_registers[1] = period;
    
    for(i = 0; i<12; i++)begin
        assign cu_read_registers[i+2] = modulation_parameters[i];
    end
    
    wire modulator_start, modulator_stop;

    assign modulator_start = triggers[0] & modulator_start_request;
    assign modulator_stop =  triggers[0] & ((~modulator_start_request & modulation_status)| modulator_stop_request);

    reg configuration_start;


    axi_stream dab_write();
    axi_stream vsi_write();
    axi_stream buck_write();
    
    wire dab_done, vsi_done, buck_done;
    wire dab_modulator_status, vsi_modulator_status;

    enum reg [1:0] {
        start_configuration_state = 0,
        wait_configuration_state = 1,
        running_state = 2
    } config_state;

    always @ (posedge clock) begin
        if (~reset) begin
            config_required <= 1;
            configuration_start <= 0;
            config_state <=start_configuration_state;
        end else begin
            case (config_state)
                start_configuration_state:begin
                    configuration_start <= 1;
                    config_required <= 1;
                    config_state <= wait_configuration_state;
                end
                wait_configuration_state:begin
                    configuration_start <= 0;
                    config_required <= 0;
                    if(dab_done || vsi_done || buck_done)begin
                        config_state <= running_state;
                    end
                end
                default:begin
                end
            endcase
        end
    end  

    
    dab_pre_modulation_processor #(
        .PWM_BASE_ADDR(PWM_BASE_ADDR),
        .N_PWM_CHANNELS(N_PWM_CHANNELS)
    ) dab_pmp (
        .clock(clock),
        .reset(reset),
        .start(modulator_start),
        .stop(modulator_stop),
        .configure(configuration_start),
        .update(triggers[4:1]),
        .modulation_type(modulation_type),
        .period(period),
        .modulation_parameters(modulation_parameters),
        .modulator_status(dab_modulator_status),
        .done(dab_done),
        .write_request(dab_write)
    );

    vsi_pre_modulation_processor  #(
        .PWM_BASE_ADDR(PWM_BASE_ADDR),
        .N_PWM_CHANNELS(N_PWM_CHANNELS)
    ) vsi_pmp (
        .clock(clock),
        .reset(reset),
        .start(modulator_start),
        .stop(modulator_stop),
        .configure(configuration_start),
        .update(triggers[4:1]),
        .period(period),
        .modulation_parameters(modulation_parameters[11:0]),
        .done(vsi_done),
        .modulator_status(vsi_modulator_status),
        .write_request(vsi_write)
    );


    buck_pre_modulation_processor  #(
        .PWM_BASE_ADDR(PWM_BASE_ADDR),
        .N_PHASES(N_CHAINS),
        .N_PWM_CHANNELS(N_PWM_CHANNELS)
    ) buck_pmp (
        .clock(clock),
        .reset(reset),
        .start(modulator_start),
        .stop(modulator_stop),
        .configure(configuration_start),
        .update(triggers[4:1]),
        .period(period),
        .modulation_parameters(modulation_parameters[11:0]),
        .done(buck_done),
        .modulator_status(buck_modulator_status),
        .write_request(buck_write)
    );

    wire [1:0] mux_selector;

    wire [2:0] modulation_status_arr = {buck_modulator_status, vsi_modulator_status, dab_modulator_status};

    generate
        if(CONVERTER_SELECTION == "DYNAMIC") begin
            assign mux_selector = converter_type;
            assign modulation_status = modulation_status_arr[converter_type];
        end else if(CONVERTER_SELECTION == "DAB") begin
            assign mux_selector = 0;
            assign modulation_status = dab_modulator_status;
        end else if(CONVERTER_SELECTION == "VSI") begin
            assign mux_selector = 1;
            assign modulation_status = vsi_modulator_status;
        end else if(CONVERTER_SELECTION == "BUCK") begin
            assign mux_selector = 2;
            assign modulation_status = buck_modulator_status;
        end
    endgenerate

    axi_stream modulator_if_write();

    axi_stream_mux_3 #(
        .DATA_WIDTH(32)
    )write_combiner(
        .clock(clock),
        .reset(reset),
        .address(mux_selector),
        .stream_in_1(dab_write),
        .stream_in_2(vsi_write),
        .stream_in_3(buck_write),
        .stream_out(modulator_if_write)
    );

    axi_stream read_req();
    assign read_req.valid = 0;

    axi_stream read_resp();
    assign read_resp.ready = 1;
    
    axis_to_axil WRITER(
        .clock(clock),
        .reset(reset), 
        .axis_write(modulator_if_write),
        .axis_read_request(read_req),
        .axis_read_response(read_resp),
        .axi_out(axi_out)
    );



endmodule

    /**
       {
        "name": "pre_modulation_processor",
        "type": "peripheral",
        "registers":[
            {
                "name": "control",
                "offset": "0x0",
                "description": "Control register",
                "direction": "RW",
                "fields": [
                    {
                        "name":"mod_type",
                        "description": "Modulation type",
                        "start_position": 0,
                        "length": 2
                    }, 
                    {
                        "name":"conv_type",
                        "description": "Converter type",
                        "start_position": 2,
                        "length": 2
                    }
                ]
            },
            {
                "name": "period",
                "offset": "0x4",
                "description": "Period of the output waveform",
                "direction": "RW"
            },
            {
                "name": "duty_1",
                "offset": "0x8",
                "description": "Duty cycle of the primary waveform",
                "direction": "RW"
            },
            {
                "name": "duty_2",
                "offset": "0xc",
                "description": "Duty cycle of the secondary waveform",
                "direction": "RW"
            },
            {
                "name": "phase_shift_1",
                "offset": "0x10",
                "description": "First phase shift parameter",
                "direction": "RW"
            },
            {
                "name": "phase_shift_2",
                "offset": "0x14",
                "description": "Second phase shift parameter",
                "direction": "RW"
            }
        ]
       }  
    **/