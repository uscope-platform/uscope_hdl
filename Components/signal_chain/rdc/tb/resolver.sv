// Copyright 2026 University of Nottingham
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

module resolver #(
    parameter real V_REF           = 3.3,   // ADC Reference / Full Scale Voltage
    parameter real TRANSFORMATION  = 0.5    // Resolver Transformation Ratio (K = V_out_pk / V_exc_pk)
)(  
    input wire clock,
    input wire reset,
    input wire sample,
    input real v_excitation,
    input real angle,
    axi_stream.master  analog_out
);

    // Continuous analog signals
    real v_sin_analog;
    real v_cos_analog;

    // Continuous-to-Digital calculations
    always_comb begin
        real v_exc_centered = v_excitation - (V_REF / 2.0);
        v_sin_analog = TRANSFORMATION * v_exc_centered * $sin(angle);
        v_cos_analog = TRANSFORMATION * v_exc_centered * $cos(angle);
    end

    // Quantized 16-bit signed ADC sample
    logic signed [15:0] adc_cos_data;

    // Time-multiplexing FSM state
    typedef enum logic {
        STATE_SIN = 1'b0,
        STATE_COS = 1'b1
    } state_e;

    state_e state;
    initial begin
            state            <= STATE_SIN;
            analog_out.valid <= 1'b0;
            analog_out.data  <= '0;
            analog_out.dest  <= '0;
            adc_cos_data     <= '0;
    end

    reg output_cos = 0;
    always_ff @(posedge clock or posedge reset) begin
        if(sample)begin
            adc_cos_data <= $rtoi((v_cos_analog / (V_REF / 2.0)) * 32767.0);
            analog_out.data  <= 16'($rtoi((v_sin_analog / (V_REF / 2.0)) * 32767.0));
            analog_out.dest  <= 1'b0; // Destination 0: SINE
            analog_out.valid <= 1'b1;
            output_cos <= 1;
        end else if(output_cos)begin
            analog_out.data  <= adc_cos_data;
            analog_out.dest  <= 1'b1; // Destination 0: SINE
            analog_out.valid <= 1'b1;
            output_cos <= 0;
        end else begin
            analog_out.valid <= 1'b0;
        end
    end

endmodule