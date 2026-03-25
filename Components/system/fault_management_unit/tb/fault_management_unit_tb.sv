// Copyright 2026 Filippo Savi
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

module fault_management_unit_tb();

    reg clk, reset;
    always begin
     clk = 1'b1;
     #0.5 clk = 1'b0;
     #0.5;
    end

    event reset_done;
    initial begin
        reset = 1;
        #5 reset = 0;
        #5 reset = 1;
        ->reset_done;
    end

    axi_lite control();
    reg [3:0] faults;
    wire fault_out, clear_fault;

    fault_management_unit #(
        .N_FAULTS(4)
    )UUT(
        .clock(clk),
        .reset(reset),
        .fault_in(faults),
        .fault_out(fault_out),
        .clear_fault(clear_fault),
        .axi_in(control)
    );

    initial begin
        faults = 0;
        @(reset_done);
        #15;
        faults = 4;
        #10 assert(fault_out == 0); // check exclusion

        #10 faults = 6;
        #10 assert(fault_out == 1); // check fault output
        faults = 0;
        #10 assert(fault_out == 1); // check sticky fault
    end

    initial begin
        control.initialize_master();
        @(reset_done);
        #20 control.write(0, 4);
    end

endmodule
