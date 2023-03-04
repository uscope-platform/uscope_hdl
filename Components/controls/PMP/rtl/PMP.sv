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
    PWM_BASE_ADDR = 0
)(
    input wire clock,
    input wire reset,
    axi_lite.slave axi_in,
    axi_lite.master axi_out
);

    reg [31:0] cu_write_registers [5:0];
    reg [31:0] cu_read_registers [5:0];

    reg config_required;
    wire [4:0] triggers;

    localparam [31:0] TRIGGER_REGISTERS_IDX [4:0] = '{2, 3, 4, 5, 0};

    axil_simple_register_cu #(
        .N_READ_REGISTERS(6),
        .N_WRITE_REGISTERS(6),
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
    reg [31:0] duty_1;
    reg [31:0] duty_2;
    reg [31:0] phase_shift_1;
    reg [31:0] phase_shift_2;

    assign {modulator_stop_request, modulator_start_request,  converter_type, modulation_type} = cu_write_registers[0];
    assign period = cu_write_registers[1];
    assign duty_1 = cu_write_registers[2];
    assign duty_2 = cu_write_registers[3];
    assign phase_shift_1 = cu_write_registers[4];
    assign phase_shift_2 = cu_write_registers[5];

    assign cu_read_registers[0] = {modulator_stop_request, modulator_start_request, converter_type, modulation_type};
    assign cu_read_registers[1] = period;
    assign cu_read_registers[2] = duty_1;
    assign cu_read_registers[3] = duty_2;
    assign cu_read_registers[4] = phase_shift_1;
    assign cu_read_registers[5] = phase_shift_2;


    assign modulator_start = triggers[0] & modulator_start_request;
    assign modulator_stop =  triggers[0] & (~modulator_start_request| modulator_stop_request);

    reg configuration_start;

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
                    if(dab_done || vsi_done)begin
                        config_state <= running_state;
                    end
                end
                default:begin
                end
            endcase
        end
    end  

    axi_stream dab_write();
    axi_stream vsi_write();
    
    wire dab_done, vsi_done;


    dab_pre_modulation_processor #(
        .PWM_BASE_ADDR(PWM_BASE_ADDR)
    ) dab_pmp (
        .clock(clock),
        .reset(reset),
        .start(modulator_start),
        .stop(modulator_stop),
        .configure(configuration_start),
        .update(triggers[4:1]),
        .modulation_type(modulation_type),
        .period(period),
        .duty_1(duty_1),
        .duty_2(duty_2),
        .phase_shift_1(phase_shift_1),
        .phase_shift_2(phase_shift_2),
        .done(dab_done),
        .write_request(dab_write)
    );


    vsi_pre_modulation_processor  #(
        .PWM_BASE_ADDR(PWM_BASE_ADDR)
    ) vsi_pmp (
        .clock(clock),
        .reset(reset),
        .start(modulator_start),
        .stop(modulator_stop),
        .configure(configuration_start),
        .update(triggers[4:1]),
        .period(period),
        .duty(duty_1),
        .done(vsi_done),
        .write_request(vsi_write)
    );

    wire [1:0] mux_selector;

    generate
        if(CONVERTER_SELECTION == "DYNAMIC")
            assign mux_selector = converter_type;
        else if(CONVERTER_SELECTION == "DAB")
            assign mux_selector = 0;
        else if(CONVERTER_SELECTION == "VSI")
            assign mux_selector = 1;
    endgenerate

    axi_stream modulator_if_write();

    axi_stream_mux_2 #(
        .DATA_WIDTH(32)
    )write_combiner(
        .clock(clock),
        .reset(reset),
        .address(mux_selector),
        .stream_in_1(dab_write),
        .stream_in_2(vsi_write),
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