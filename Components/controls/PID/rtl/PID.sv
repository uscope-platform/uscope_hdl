

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

module PID #(
    parameter INPUT_DATA_WIDTH = 12, 
    parameter OUTPUT_DATA_WIDTH = 16
    )(
    input wire clock,
    input wire reset,

    // PID
    axi_stream.slave reference,
    axi_stream.slave feedback,
    axi_stream.master out,
    axi_stream.master error_mon,
    axi_lite.slave axil
);

    typedef struct {
        reg [31:0] nonblocking_output;
        reg [31:0] kP;
        reg [31:0] kI;
        reg [31:0] kD;
        reg signed [31:0] limit_out_up;
        reg signed [31:0] limit_out_down;
        reg signed [31:0] limit_int_up;
        reg signed [31:0] limit_int_down;
        reg [31:0] denominators;
    } pid_registers;

    pid_registers registers;
    pid_registers inital_values = '{
        limit_out_up: 16'sd32767,
        limit_int_up: 16'sd32767,
        limit_out_down: -16'sd32767,
        limit_int_down: -16'sd32767,
        denominators: 'h010101,
        default:0
    }

    axil_simple_register_cu #(
        .READ_TYPE(pid_registers),
        .WRITE_TYPE(pid_registers),
        .REGISTERS_WIDTH(32),
        .ADDRESS_MASK('hff),
        .INITIAL_OUTPUT_VALUES(inital_values)
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(registers),
        .output_registers(registers),
        .axil(axil)
    );


    assign reference.ready = 1;
    assign feedback.ready = 1;
    
    // Top level parameters
    reg signed [OUTPUT_DATA_WIDTH-1:0] error;
    reg signed [OUTPUT_DATA_WIDTH-1:0] integrator_in;

    reg signed [OUTPUT_DATA_WIDTH-1:0] propotional_out;
    wire signed [OUTPUT_DATA_WIDTH-1:0] integral_out;
    wire signed [OUTPUT_DATA_WIDTH-1:0] diff_out;

    reg signed [OUTPUT_DATA_WIDTH-1:0] differential_out;
    reg signed [OUTPUT_DATA_WIDTH-1:0] int_pid_out;

    wire inputs_valid;
    assign inputs_valid = reference.valid && feedback.valid;

    reg error_valid, integrator_in_valid, integrator_out_valid;

    assign diff_out = 0;

    reg [7:0] kP_den;
    reg [7:0] kI_den;
    reg [7:0] kD_den;

    assign {kD_den, kI_den, kP_den} = registers.denominators;


    
    Integrator #(
        .DATA_WIDTH(OUTPUT_DATA_WIDTH)
    ) pid_int(
        .clock(clock),
        .reset(reset),
        // PID
        .input_valid(integrator_in_valid),
        .limit_int_up(limit_int_up),
        .limit_int_down(limit_int_down),
        .error_in(integrator_in),
        .out(integral_out)
    );

   always@(posedge clock)begin
       if(~reset) begin
            error <= 0;
            error_valid <= 0;
        end else begin
            if(inputs_valid & (out.ready | registers.nonblocking_output[0])) begin
                error <= reference.data - feedback.data;
                error_valid <=1;
            end else begin
                error_valid <= 0;
            end
        end
   end

    assign error_mon.data = error;
    assign error_mon.valid = error_valid;

    always@(posedge clock)begin
        if(~reset) begin
            propotional_out <= 0;
            differential_out <= 0;
            integrator_in <= 0;
            integrator_in_valid <=0;
            integrator_out_valid <= 0;
        end else begin
            integrator_out_valid <= integrator_in_valid;
            if(error_valid & (out.ready | registers.nonblocking_output[0])) begin
                propotional_out <= ($signed(registers.kP) * error) >>> kP_den;
                integrator_in <= ($signed(registers.kI) * error) >>> kI_den;
                differential_out <= ($signed(registers.kD) * diff_out) >>> kD_den;
                integrator_in_valid <=1;    
            end else begin
                integrator_in_valid <=0;
            end
        end
    end
    

    always@(posedge clock)begin
        if(~reset) begin
            int_pid_out <= 0;
            out.valid <= 0;
        end else begin
            if(integrator_out_valid && out.ready) begin
                int_pid_out <= propotional_out + integral_out;  
                out.valid <= 1;
            end else begin
                out.valid <= 0;
            end
        end
    end
   
    always@(*)begin
        if(~reset) begin
            out.data <= 0;
        end else begin
            if (int_pid_out > registers.limit_out_up) begin 
                out.data <= registers.limit_out_up;
            end else if (int_pid_out < registers.limit_out_down) begin 
                out.data <= registers.limit_out_down;    
            end else begin 
                out.data <= int_pid_out;
            end
        end

    end


endmodule

    /**
       {
        "name": "PID",
        "type": "parametric_peripheral",
        "registers":[
            {
                "name": "control",
                "n_regs": ["1"],
                "description": "Control register",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "kp",
                "n_regs": ["1"],
                "description": "Proportional action gain",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "ki",
                "n_regs": ["1"],
                "description": "Integral action gain",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "kd",
                "n_regs": ["1"],
                "description": "Derivative action gain",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "limit_out_p",
                "n_regs": ["1"],
                "description": "Upper output saturation limit",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "limit_out_n",
                "n_regs": ["1"],
                "description": "Lower output saturation limit",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "limit_int_p",
                "n_regs": ["1"],
                "description": "Upper integrator saturation limit",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "limit_int_n",
                "n_regs": ["1"],
                "description": "Lower integrator saturation limit",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "gain_scaling",
                "n_regs": ["1"],
                "description": "Gain scaling factor",
                "direction": "RW",
                "fields": [
                    {
                        "name":"kp_den",
                        "description": "Proportional action scaling factor",
                        "n_fields":["1"],
                        "start_position": 0,
                        "length": 8
                    },
                    {
                        "name":"ki_den",
                        "description": "Integral action scaling factor",
                        "n_fields":["1"],
                        "start_position": 8,
                        "length": 8
                    },
                    {
                        "name":"kd_den",
                        "description": "derivative action scaling factor",
                        "n_fields":["1"],
                        "start_position": 16,
                        "length": 8
                    }
                ]
            }
        ]
       }  
    **/