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

`timescale 10ns / 1ns
`include "interfaces.svh"

module ultra_buffer_tb();

    reg  clock, reset;

    event test_done;
    axi_stream stream_in();
    axi_stream stream_out();


    //clock generation
    initial clock = 0; 
    always #0.5 clock = ~clock; 

    reg trigger = 0;
    wire full;

    ultra_buffer #(
        .ADDRESS_WIDTH(5),
        .IN_DATA_WIDTH(32),
        .DEST_WIDTH(16),
        .USER_WIDTH(16)
    )UUT(
        .clock(clock),
        .reset(reset),
        .enable(1),
        .trigger(trigger),
        .trigger_point(10),
        .full(full),
        .in(stream_in),
        .out(stream_out)
    );

    

    event config_done;

    initial begin
        reset <=1'h1;
        #1 reset <=1'h0;
        //TESTS
        #5.5 reset <=1'h1;
        #10;
        ->config_done;
        forever begin
            #60 trigger <= 1;
            #1 trigger <= 0;
            #35000;
        end
    end 

    reg [15:0] data_ctr = 0;
    reg stop_test = 0;

    always_ff @(posedge clock)begin
        if(stream_out.valid) stop_test <= 1;
    end

    initial begin
        stream_in.valid <= 0;
        stream_in.data <= 0;
        stream_in.dest <= 0;
        stream_in.user <= 0;
        @(config_done);
        forever begin
            if(!stop_test)begin
                wait(stream_in.ready == 1);
                stream_in.valid <= 1;
                stream_in.data <= data_ctr;
                stream_in.dest <= 5;
                stream_in.user <= 'h28;
                data_ctr <= data_ctr + 1;
                #1 stream_in.valid <= 0;
            end
            #3;
        end
    end
    
    localparam mem_depth = (1<<5);
    reg[31:0] check_data [mem_depth-1:0];
    reg[31:0] result_data [mem_depth-1:0];

    reg [5:0] result_ctr = 0;
    event do_result_check;
    always_ff@(posedge clock)begin
        if(stream_in.valid)begin
            for(int i = 0; i<mem_depth; i++)begin
                check_data[mem_depth-i-1] <= check_data[mem_depth-i];
            end
            check_data[mem_depth-1] <=  stream_in.data;
        end

        if(stream_out.valid && stream_out.ready)begin
            result_data[result_ctr] <= stream_out.data;
            result_ctr <= result_ctr + 1;
            if(result_ctr == mem_depth-1) ->do_result_check;
        end
    end



    always begin
        @(do_result_check)begin
        #1;
        assert (check_data == result_data) 
            else  $fatal("ERROR: wrong result detected");
        end
    end





    initial begin
    
        stream_out.ready <= 1;
        #0.5;
        #18000;
        stream_out.ready <= 0;
        # 5;
        stream_out.ready <= 1;
    end

endmodule