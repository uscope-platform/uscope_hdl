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

module exc_filter #(
    // -------------------------------------------------------------------------
    // SAMPLING & TIME STEP PARAMETERS
    // -------------------------------------------------------------------------
    parameter real F_SAMPLE = 50.0e6,         // DAC / Sample Clock Frequency in Hz (e.g., 50 MHz)
    parameter real DT       = 1.0 / F_SAMPLE, // Fixed integration time step in seconds

    // -------------------------------------------------------------------------
    // HARDWARE COMPONENT VALUES
    // -------------------------------------------------------------------------
    parameter real R0 = 220.0,  C0 = 1.0e-9,  // RC Stage
    parameter real R1 = 2200.0, R2 = 2200.0, // Sallen-Key Resistors
    parameter real C1 = 1.0e-9, C2 = 1.0e-9,  // Sallen-Key Capacitors

    parameter real V_HIGH = 3.3,
    parameter real V_LOW  = 0.0
)(
    input wire clk_sample,      // Drive this with your high-speed DAC clock (e.g. 10MHz - 100MHz)
    input wire dac_bitstream,
    output real v_excitation
);

    real x0 = 0.0, x1 = 0.0;
    real y_rc0 = 0.0, y_rc1 = 0.0;

    real x_sk0 = 0.0, x_sk1 = 0.0, x_sk2 = 0.0;
    real y_sk0 = 0.0, y_sk1 = 0.0, y_sk2 = 0.0;

    localparam real M_PI = 3.14159265358979323846;

    // =========================================================================
    // 1. CALCULATE CUTOFF FREQUENCIES (Hz)
    // =========================================================================
    localparam real FC_RC = 1.0 / (2.0 * M_PI * R0 * C0);
    localparam real FC_SK = 1.0 / (2.0 * M_PI * $sqrt(R1 * R2 * C1 * C2));

    // =========================================================================
    // 2. PRE-WARPED BILINEAR TRANSFORM FACTORS
    // =========================================================================
    localparam real K_RC = 1.0 / $tan(M_PI * FC_RC / F_SAMPLE);
    localparam real K_SK = 1.0 / $tan(M_PI * FC_SK / F_SAMPLE);

    // =========================================================================
    // 3. DERIVE STAGE 1 (RC) COEFFICIENTS
    // =========================================================================
    localparam real RC_GAIN = 1.0 + K_RC;
    
    localparam real RC_B0 =  1.0 / RC_GAIN;
    localparam real RC_B1 =  1.0 / RC_GAIN;
    localparam real RC_A1 = (1.0 - K_RC) / RC_GAIN;

    // =========================================================================
    // 4. DERIVE STAGE 2 (SALLEN-KEY) COEFFICIENTS
    // =========================================================================
    localparam real SK_GAIN = (K_SK * K_SK) + (2.0 * K_SK) + 1.0;

    localparam real SK_B0 = 1.0 / SK_GAIN;
    localparam real SK_B1 = 2.0 / SK_GAIN;
    localparam real SK_B2 = 1.0 / SK_GAIN;

    localparam real SK_A1 = (2.0 * (1.0 - (K_SK * K_SK))) / SK_GAIN;
    localparam real SK_A2 = ((K_SK * K_SK) - (2.0 * K_SK) + 1.0) / SK_GAIN;





    always_ff @(posedge clk_sample) begin
        // ---------------------------------------------------------------------
        // Input Sample Map
        // ---------------------------------------------------------------------
        x0 <= dac_bitstream ? V_HIGH : V_LOW;
        x1 <= x0;

        // ---------------------------------------------------------------------
        // Stage 1: RC Filter Pipeline
        // ---------------------------------------------------------------------
        y_rc0 <= (RC_B0 * x0) + (RC_B1 * x1) - (RC_A1 * y_rc0);

        // ---------------------------------------------------------------------
        // Stage 2: Sallen-Key Filter Pipeline (Inputs from y_rc0)
        // ---------------------------------------------------------------------
        x_sk0 <= y_rc0;
        x_sk1 <= x_sk0;
        x_sk2 <= x_sk1;

        y_sk0 <= (SK_B0 * x_sk0) + (SK_B1 * x_sk1) + (SK_B2 * x_sk2)
               - (SK_A1 * y_sk0) - (SK_A2 * y_sk1);

        y_sk1 <= y_sk0;
    end

    assign v_excitation = y_sk0;

    reg [63:0] rc_out;
      
    always_ff @(posedge clk_sample ) begin
        rc_out <= $realtobits(y_rc0);
    end

endmodule