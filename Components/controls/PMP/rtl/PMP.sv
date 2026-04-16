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

module pre_modulation_processor #(
    CONVERTER_SELECTION = "",
    BASE_ADDRESS = 0,
    PWM_BASE_ADDR = 0,
    N_PWM_CHANNELS = 4,
    N_PARAMETERS = 13,
    N_CHAINS = 2,
    parameter [31:0] INITIAL_PARAMETERS_VALUES [N_PARAMETERS+1:0] = '{default:0}
)(
    input wire clock,
    input wire reset,
    input wire external_start,
    input wire external_stop,
    axi_lite.slave axi_in,
    axi_stream.slave modulation_in,
    axi_stream.watcher duty_repeater,
    output reg modulator_ready,
    axi_stream modulation_out
);

    axi_stream cu_write();
    axi_stream cu_read_addr();
    axi_stream cu_read_data();

    reg [N_PWM_CHANNELS:0] triggers;
    reg config_required;

    wire modulation_status;

    reg [31:0] cu_write_registers [N_PARAMETERS+1:0] = INITIAL_PARAMETERS_VALUES;
    reg [31:0] cu_read_registers [N_PARAMETERS+1:0];

    axil_external_registers_cu #(
        .REGISTERS_WIDTH(32),
        .REGISTERED_BUFFERS(0),
        .BASE_ADDRESS(BASE_ADDRESS),
        .READ_DELAY(0)
    )CU (
        .clock(clock),
        .reset(reset | ~config_required),
        .read_address(cu_read_addr),
        .read_data(cu_read_data),
        .write_data(cu_write),
        .axi_in(axi_in)
    );

    assign modulation_in.ready = 1;


    typedef logic [31:0] triggers_init_t [N_PWM_CHANNELS:0];
    function triggers_init_t TRIGGERS_CALC();
        TRIGGERS_CALC[0] = 0;
        for(int i = 0; i<N_PWM_CHANNELS; i++)begin
            TRIGGERS_CALC[i+1] =2+i;
        end
    endfunction

    localparam [31:0] TRIGGER_REGISTERS_IDX [N_PWM_CHANNELS:0] = TRIGGERS_CALC();


    always_ff@(posedge clock) begin 
        triggers <= 0;
        cu_write.ready <= 1;
        cu_read_addr.ready <= 1;
        if(cu_write.valid)begin
            cu_write_registers[cu_write.dest] <= cu_write.data;
            for(integer i = 0; i<N_PWM_CHANNELS+1; i= i+1)begin
                if(cu_write.dest == TRIGGER_REGISTERS_IDX[i]) begin
                    triggers[i] <= 1'b1;
                end
            end
        end

        if(modulation_in.valid)begin
            cu_write_registers[modulation_in.dest] <= modulation_in.data;
            for(integer i = 0; i< N_PWM_CHANNELS+1; i= i+1)begin
                if(modulation_in.dest == TRIGGER_REGISTERS_IDX[i]) begin
                    triggers[i] <= 1'b1;
                end
            end
        end

        if(cu_read_addr.valid)begin
            cu_read_data.data <= cu_read_registers[cu_read_addr.data];
        end
        cu_read_data.valid <= cu_read_addr.valid;
        
    end

    initial begin
        if(CONVERTER_SELECTION != "BUCK" && CONVERTER_SELECTION != "VSI" && CONVERTER_SELECTION != "DAB")begin
            $display("Invalid converter type: %s\n", CONVERTER_SELECTION);
            $error(" Converter type should be one of the following {VSI, BUCK, DAB}");
        end
    end

    reg [1:0] modulation_type;
    reg [31:0] period;
    
    reg [15:0] modulation_parameters [N_PARAMETERS-1:0];

    assign modulation_type = cu_write_registers[0];
    assign period = cu_write_registers[1];
    
    genvar i;
    for(i = 0; i<N_PARAMETERS; i++)begin
        assign modulation_parameters[i] = cu_write_registers[i+2];
    end
    

    assign cu_read_registers[0] =  modulation_type;
    assign cu_read_registers[1] = period;
    
    for(i = 0; i<N_PARAMETERS; i++)begin
        assign cu_read_registers[i+2] = modulation_parameters[i];
    end

    reg configuration_start;

    wire done, pmp_busy;

    enum reg [1:0] {
        start_configuration_state = 0,
        wait_configuration_state = 1,
        running_state = 2
    } config_state;

    always @ (posedge clock) begin
        modulator_ready <= config_state == running_state && ~pmp_busy;
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
                    if(done)begin
                        config_state <= running_state;
                    end
                end
                default:begin
                end
            endcase
        end
    end  


    generate

        if(CONVERTER_SELECTION == "DAB") begin
            

            dab_pre_modulation_processor #(
                .PWM_BASE_ADDR(PWM_BASE_ADDR),
                .N_PWM_CHANNELS(N_PWM_CHANNELS),
                .N_PARAMETERS(N_PARAMETERS)
            ) dab_pmp (
                .clock(clock),
                .reset(reset),
                .start(external_start),
                .stop(external_stop),
                .configure(configuration_start),
                .update(triggers[N_PWM_CHANNELS:1]),
                .modulation_type(modulation_type),
                .period(period),
                .modulation_parameters(modulation_parameters),
                .modulator_status(modulation_status),
                .done(done),
                .busy(pmp_busy),
                .duty_repeater(duty_repeater),
                .write_request(modulation_out)
            );
        end else if(CONVERTER_SELECTION == "VSI") begin
            

            vsi_pre_modulation_processor  #(
                .PWM_BASE_ADDR(PWM_BASE_ADDR),
                .N_PWM_CHANNELS(N_PWM_CHANNELS),
                .N_PARAMETERS(N_PARAMETERS)
            ) vsi_pmp (
                .clock(clock),
                .reset(reset),
                .start(external_start),
                .stop(external_stop),
                .configure(configuration_start),
                .update(triggers[N_PWM_CHANNELS:1]),
                .period(period),
                .modulation_parameters(modulation_parameters),
                .done(done),
                .busy(pmp_busy),
                .modulator_status(modulation_status),
                .write_request(modulation_out)
            );

        end else if(CONVERTER_SELECTION == "BUCK") begin
            
            
            buck_pre_modulation_processor  #(
                .PWM_BASE_ADDR(PWM_BASE_ADDR),
                .N_PHASES(N_CHAINS),
                .N_PWM_CHANNELS(N_PWM_CHANNELS),
                .N_PARAMETERS(N_PARAMETERS)
            ) buck_pmp (
                .clock(clock),
                .reset(reset),
                .start(external_start),
                .stop(external_stop),
                .configure(configuration_start),
                .update(triggers[N_PWM_CHANNELS:1]),
                .period(period),
                .modulation_parameters(modulation_parameters),
                .done(done),
                .busy(pmp_busy),
                .duty_repeater(duty_repeater),
                .modulator_status(modulation_status),
                .write_request(modulation_out)
            );
        end
    endgenerate


endmodule

    /**
    {
        "name": "pre_modulation_processor",
        "type": "variant_peripheral",
        "variant_parameter":"CONVERTER_SELECTION",
        "registers":[
            {
                "name": "control",
                "n_regs": ["1"],
                "description": "Control register",
                "direction": "RW",
                "fields": [
                    {
                        "name":"mod_type",
                        "description": "Modulation type",
                        "n_fields":["1"],
                        "start_position": 0,
                        "length": 2
                    }, 
                    {
                        "name":"conv_type",
                        "description": "Converter type",
                        "n_fields":["1"],
                        "start_position": 2,
                        "length": 2
                    }
                ],
                "variants":["DAB", "VSI", "BUCK", "DYNAMIC"]
            },
            {
                "name": "period",
                "n_regs": ["1"],
                "description": "Period of the output waveform",
                "direction": "RW",
                "variants":["DAB", "VSI", "BUCK", "DYNAMIC"]
            },
            {
                "name": "duty_1",
                "n_regs": ["1"],
                "description": "Duty cycle of the primary waveform",
                "direction": "RW",
                "variants":["DAB"]
            },
            {
                "name": "duty_2",
                "n_regs": ["1"],
                "description": "Duty cycle of the secondary waveform",
                "direction": "RW",
                "variants":["DAB"]
            },
            {
                "name": "phase_shift_1",
                "n_regs": ["1"],
                "description": "First phase shift parameter",
                "direction": "RW",
                "variants":["DAB"]
            },
            {
                "name": "phase_shift_2",
                "n_regs": ["1"],
                "description": "Second phase shift parameter",
                "direction": "RW",
                "variants":["DAB"]
            },
            {
                "name": "deadime",
                "n_regs": ["1"],
                "description": "Deadtime",
                "direction": "RW",
                "variants":["DAB"]
            },
            {
                "name": "duty_$",
                "n_regs": ["N_CHAINS"],
                "description": "Duty cycle for phase $",
                "direction": "RW",
                "variants":["BUCK"]
            },
            {
                "name": "deadtime",
                "n_regs": ["1"],
                "description": "Deadtime between high and low side for buck converter",
                "direction": "RW",
                "variants":["BUCK"]
            }
        ]
    }
    **/