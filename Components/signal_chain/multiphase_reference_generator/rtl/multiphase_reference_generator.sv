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
`timescale 10ns / 1ns
`include "interfaces.svh"

module multiphase_reference_generator #(parameter N_PHASES=6, DATA_PATH_WIDTH=16, BASE_ADDRESS='h43c00000)(
    input wire clock,
    input wire reset,
    input wire sync,
    input wire [DATA_PATH_WIDTH-1:0] Id,
    input wire [DATA_PATH_WIDTH-1:0] Iq,
    input wire [15:0] phase_shifts [N_PHASES-1:0],
    output wire angle_emulation,
    axi_stream.master angle_out,
    axi_stream.slave phase,
    axi_stream.master reference_out,
    Simplebus sb
);

    reg emulate_angle;
    reg [31:0] emulation_sampling_period;
    reg [31:0] emulation_phase_advance;
    reg [31:0] emulator_tb;
    reg [15:0] emulator_counter;

    assign angle_emulation = emulate_angle;

    defparam emulated_phase.DATA_WIDTH = 16;
    axi_stream emulated_phase();
    
    defparam gen_cu.BASE_ADDRESS=BASE_ADDRESS;
    multiphase_reference_generator_CU gen_cu(
        .clock(clock),
        .reset(reset),
        .emulation_mode(emulate_angle),
        .emulation_phase_advance(emulation_phase_advance),
        .emulation_sampling_period(emulation_sampling_period),
        .sb(sb)
    );

    
    enable_generator_counter angle_emulator_tb(
        .clock(clock),
        .reset(reset),
        .gen_enable_in(emulate_angle),
        .period(emulation_sampling_period),
        .counter_out(emulator_tb)
    );


    always_ff @(posedge clock)begin
        if(~reset)begin
            emulator_counter <= 0;
            emulated_phase.data <= 0;
            emulated_phase.valid <= 0;
        end else begin
            if(phase.valid)begin
                emulated_phase.data <= emulator_counter;
                emulated_phase.valid <= 1;
            end else begin
                emulated_phase.valid <= 0;
            end
            if(emulator_tb == 1) begin
                emulator_counter <= emulator_counter + emulation_phase_advance;
            end
        end
    end

    axi_stream generator_inner_phase();

    always_comb begin
        if(emulate_angle)begin
            generator_inner_phase.data <= emulated_phase.data;
            generator_inner_phase.valid <= emulated_phase.valid;
            emulated_phase.ready <= generator_inner_phase.ready;
            phase.ready <= 1;
        end else begin
            generator_inner_phase.data <= phase.data;
            generator_inner_phase.valid <= phase.valid;
            phase.ready <= generator_inner_phase.ready;
            emulated_phase.ready <= 1;
        end
    end

    assign angle_out.data = generator_inner_phase.data;
    assign angle_out.valid = generator_inner_phase.valid;

    defparam sin.DATA_WIDTH = DATA_PATH_WIDTH;
    axi_stream sin();
    defparam cos.DATA_WIDTH = DATA_PATH_WIDTH;
    axi_stream cos();

    defparam quadrature_generator.N_PHASES = N_PHASES;
    multiphase_sinusoid_generator quadrature_generator(
        .clock(clock),
        .reset(reset),
        .phase(generator_inner_phase),
        .phase_shifts(phase_shifts),
        .sin_out(sin),
        .cos_out(cos)
    );

    reg [DATA_PATH_WIDTH-1:0] latched_Id;
    reg [DATA_PATH_WIDTH-1:0] latched_Iq;
    reg [DATA_PATH_WIDTH-1:0] internal_reference_data [N_PHASES-1:0];
    
    wire signed [2*DATA_PATH_WIDTH-1:0] id_factor;
    wire signed [2*DATA_PATH_WIDTH-1:0] iq_factor;
    
    assign id_factor = ($signed(latched_Id)*$signed(sin.data));
    assign iq_factor = -($signed(latched_Iq)*$signed(cos.data));

    wire [DATA_PATH_WIDTH-1:0] scaled_id_factor;
    wire [DATA_PATH_WIDTH-1:0] scaled_iq_factor;

    assign scaled_id_factor = id_factor >>> (DATA_PATH_WIDTH-1);
    assign scaled_iq_factor = iq_factor >>> (DATA_PATH_WIDTH-1);

    always_ff@(posedge clock) begin
        if(~reset) begin
            for(int i = 0; i< N_PHASES; i++)begin
                internal_reference_data[i]<= 0;
            end
        end else begin
            if(generator_inner_phase.valid) begin
                latched_Id <= Id;
                latched_Iq <= Iq;
            end
            if(sin.valid)begin
                internal_reference_data[sin.dest] <= scaled_id_factor + scaled_iq_factor;
            end
        end
    end

    reg [$clog2(N_PHASES)-1:0] output_phase_counter;
    reg sync_delay;
    always_ff@(posedge clock)begin
        if(~reset)begin
            reference_out.data <= 0;
            reference_out.valid <= 0;
            reference_out.dest <= 0;
            output_phase_counter <= 0;
        end else begin
            reference_out.valid <= 0;
            sync_delay <= sync;
            if(output_phase_counter != 0)begin
                reference_out.data <= internal_reference_data[output_phase_counter];
                reference_out.dest <= output_phase_counter;
                reference_out.valid <= 1;
                output_phase_counter <= output_phase_counter +1;
                if(output_phase_counter == N_PHASES-1)begin
                    output_phase_counter <= 0;
                end
            end 
            if(sync_delay)begin
                reference_out.data <= internal_reference_data[output_phase_counter];
                reference_out.dest <= output_phase_counter;
                reference_out.valid <= 1;
                output_phase_counter <= 1;
            end
        end
    end


endmodule