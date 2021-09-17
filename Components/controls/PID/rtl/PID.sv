

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

module PID #(parameter BASE_ADDRESS = 32'h43c00000, parameter INPUT_DATA_WIDTH = 12, parameter OUTPUT_DATA_WIDTH = 16)(
    input wire clock,
    input wire reset,

    // PID
    axi_stream.slave reference,
    axi_stream.slave feedback,
    axi_stream.master out,
    axi_stream.master error_mon,
    Simplebus.slave sb
);

  // PID parameters
    wire [OUTPUT_DATA_WIDTH-1:0] kP;
    wire [OUTPUT_DATA_WIDTH-1:0] kI;
    wire [OUTPUT_DATA_WIDTH-1:0] kD;
    wire [7:0] kP_den;
    wire [7:0] kI_den;
    wire [7:0] kD_den;
    wire signed [OUTPUT_DATA_WIDTH-1:0] limit_out_up;
    wire signed [OUTPUT_DATA_WIDTH-1:0] limit_out_down;
    wire signed [OUTPUT_DATA_WIDTH-1:0] limit_int_up;
    wire signed [OUTPUT_DATA_WIDTH-1:0] limit_int_down;


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

    wire inputs_valid, nonblocking_output;
    assign inputs_valid = reference.valid && feedback.valid;


    reg error_valid, integrator_in_valid, integrator_out_valid;

    assign diff_out = 0;


    defparam pid_int.DATA_WIDTH = OUTPUT_DATA_WIDTH;
    Integrator pid_int(
        .clock(clock),
        .reset(reset),
        // PID
        .input_valid(integrator_in_valid),
        .limit_int_up(limit_int_up),
        .limit_int_down(limit_int_down),
        .error_in(integrator_in),
        .out(integral_out)
    );


    defparam PIDControlUnit.DATA_WIDTH = OUTPUT_DATA_WIDTH;
    defparam PIDControlUnit.BASE_ADDRESS = BASE_ADDRESS;
    PIDControlUnit PIDControlUnit(
        .clock(clock),
        .reset(reset),
        .sb(sb),
        .kP(kP),
        .kP_den(kP_den),
        .kI(kI),
        .kI_den(kI_den),
        .kD(kD),
        .kD_den(kD_den),
        .nonblocking_output(nonblocking_output),
        .limit_out_up(limit_out_up),
        .limit_out_down(limit_out_down),
        .limit_int_up(limit_int_up),
        .limit_int_down(limit_int_down)
    );

   always@(posedge clock)begin
       if(~reset) begin
            error <= 0;
            error_valid <= 0;
        end else begin
            if(inputs_valid & (out.ready | nonblocking_output)) begin
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
            if(error_valid & (out.ready | nonblocking_output)) begin
                propotional_out <= ($signed(kP) * error) >>> kP_den;
                integrator_in <= ($signed(kI) * error) >>> kI_den;
                differential_out <= ($signed(kD) * diff_out) >>> kD_den;
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
            if (int_pid_out > limit_out_up) begin 
                out.data <= limit_out_up;
            end else if (int_pid_out < limit_out_down) begin 
                out.data <= limit_out_down;    
            end else begin 
                out.data <= int_pid_out;
            end
        end

    end


endmodule