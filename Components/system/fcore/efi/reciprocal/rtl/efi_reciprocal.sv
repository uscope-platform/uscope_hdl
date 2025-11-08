// Copyright 2024 Filippo Savi
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

module efi_reciprocal #(
    parameter DATA_PATH_WIDTH = 16
)(
    input wire clock,
    input wire reset,
    axi_stream.slave efi_arguments,
    axi_stream.master efi_results
);

    reg [15:0] reciprocal_lut [511:0];


    initial begin : INIT
        $readmemh("rec_lut.mem", reciprocal_lut);
    end


    enum logic [1:0] {
        fsm_idle = 0,
        fsm_calculate = 1
    } efi_trig_fsm = fsm_idle;


    always_ff @(posedge clock)begin
        case (efi_trig_fsm)
            fsm_idle:begin
                if(efi_arguments.valid)begin
                    efi_trig_fsm <= fsm_calculate;
                end else begin
                    efi_results.data <= 0;
                    efi_results.valid<=0;
                    efi_arguments.ready <= 1;
                    efi_results.tlast<=0;
                end
            end
            fsm_calculate:begin
                efi_trig_fsm <= fsm_idle;
                efi_results.data <= reciprocal_lut[efi_arguments.data];
                efi_results.dest <= efi_arguments.dest-2;
                efi_results.valid<=1;
                efi_results.tlast<=1;
            end
        endcase
    end


endmodule