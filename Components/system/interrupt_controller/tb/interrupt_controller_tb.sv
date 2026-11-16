// Copyright 2023 Filippo Savi
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
`timescale 10ns / 100ps
`include "axi_lite_BFM.svh"

module interrupt_controller_tb();

    reg clk, rst;
    event reset_done;

    initial begin
        rst <=0;
        #10 rst <=1;
        ->reset_done;
    end

    //clock generation
    initial clk = 1; 
    always #0.5 clk = ~clk; 
    
    reg [2:0] irq_in;

    wire irq_out;

    axi_lite_BFM axi_bfm;
    axi_lite axi_ctrl();
    reg[31:0] read_result;

    interrupt_controller #(
        .N_INTERRUPTS(3)
    )irq_controller(
        .clock(clk),
        .reset(rst),
        .interrupt_in(irq_in),
        .irq(irq_out),
        .axi_in(axi_ctrl)
    );

    initial begin
        axi_bfm = new(axi_ctrl,1);
        @(reset_done);
        // CHECK IRQ FIRING
        #40 irq_in = 1;
        #2 assert(irq_out) else begin
            $display("------------------------------------------------------------");
            $display("------------------------------------------------------------");
            $display("THE OUTPUT IRQ IS NOT ASSERTED ON  IRQ");
            $display("------------------------------------------------------------");
            $display("------------------------------------------------------------");
            $stop();
        end
        
        axi_bfm.read(0,read_result);
        assert(read_result == 1)else begin
            $display("------------------------------------------------------------");
            $display("------------------------------------------------------------");
            $display("Read %d in the status register instead of 1",read_result);
            $display("------------------------------------------------------------");
            $display("------------------------------------------------------------");
            $stop();
        end
        // CHECK SECOND IRQ PRESENCE
        #20 irq_in = 5;
        #1 assert(irq_out) else  begin
            $display("------------------------------------------------------------");
            $display("------------------------------------------------------------");
            $display("THE OUTPUT IRQ IS NOT ASSERTED ON  IRQ");
            $display("------------------------------------------------------------");
            $display("------------------------------------------------------------");
            $stop();
        end
        axi_bfm.read(0,read_result);
        assert(read_result == 5) else begin
            $display("------------------------------------------------------------");
            $display("------------------------------------------------------------");
            $display("Read %d in the status register instead of 5", read_result);
            $display("------------------------------------------------------------");
            $display("------------------------------------------------------------");
            $stop();
        end
        irq_in = 0;
        //CLEAR FIRST INTERRUPT AND CHECK THAT IRQ OUT IS STILL ASSERTED
        axi_bfm.write(0,1);
        #1 assert(irq_out) else begin
            $display("------------------------------------------------------------");
            $display("------------------------------------------------------------");
            $display("THE OUTPUT IRQ IS NOT ASSERTED ON  IRQ");
            $display("------------------------------------------------------------");
            $display("------------------------------------------------------------");
            $stop();
        end
        axi_bfm.read(0,read_result);
        assert(read_result == 4) else  begin
            $display("------------------------------------------------------------");
            $display("------------------------------------------------------------");
            $display("Read %d in the status register instead of 4", read_result);
            $display("------------------------------------------------------------");
            $display("------------------------------------------------------------");
            $stop();
        end
        //CLEAR BOTH INTERRUPTS AND CHECK THAT IRQ OUT IS CLEARED
        axi_bfm.write(0,5);
        #2 assert(!irq_out) else begin
            $display("------------------------------------------------------------");
            $display("------------------------------------------------------------");
            $display("THE OUTPUT IRQ IS STILL ASSERTED AFTER CLEARING");
            $display("------------------------------------------------------------");
            $display("------------------------------------------------------------");
            $stop();
        end
        
        axi_bfm.read(0,read_result);
        assert(read_result == 0) else begin
            $display("------------------------------------------------------------");
            $display("------------------------------------------------------------");
            $display("Read %d in the status register instead of 0", read_result);
            $display("------------------------------------------------------------");
            $display("------------------------------------------------------------");
            $stop();
        end

    end



endmodule
