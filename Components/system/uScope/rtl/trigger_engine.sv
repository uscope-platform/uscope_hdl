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


module trigger_engine #(
    N_CHANNELS = 6,
    MEMORY_DEPTH = 1023
)(
    input wire        clock,
    input wire        reset,
    axi_stream.slave data_in[N_CHANNELS],
    axi_lite.slave axi_in,
    output reg trigger_out,
    output reg [15:0] trigger_point,
    output reg [63:0] dma_base_addr
);

    

    typedef struct packed{
        logic [29:0] rsvd_1; logic [1:0]  trigger_mode; // PADDED
        logic [31:0] trigger_level;
        logic [31:0] buffer_addr_low;
        logic [31:0] buffer_addr_high;
        logic [23:0] rsvd_2; logic [7:0]  channel_selector; // PADDED
        logic [15:0] rsvd_3; logic [15:0] trigger_point; // PADDED
        logic [29:0] rsvd_4; logic [1:0]  acquisition_mode; // PADDED
        logic [31:0]rearm_status;
    } hil_controller_registers;
    
    enum reg [2:0] {
        wait_fill = 0,
        run = 1,
        stop = 2,
        free_run = 3
    } scope_state = wait_fill;

    wire rearm_trigger;
    
    hil_controller_registers write_registers, read_registers;

    always_comb begin
        read_registers = write_registers;
        read_registers.rearm_status = 32'(scope_state);
    end

    axil_simple_register_cu #(
        .READ_TYPE(hil_controller_registers),
        .WRITE_TYPE(hil_controller_registers),
        .ADDRESS_MASK('h1f),
        .TRIGGER_MASK('{rearm_status: 1, default: 0})
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(read_registers),
        .output_registers(write_registers),
        .trigger_out(rearm_trigger),
        .axil(axi_in)
    );

    assign dma_base_addr = {write_registers.buffer_addr_high, write_registers.buffer_addr_low};
    assign trigger_point = write_registers.trigger_point;

    wire[31:0] unrolled_data [N_CHANNELS-1:0];
    wire [15:0] unrolled_user [N_CHANNELS-1:0];
    wire unrolled_valid [N_CHANNELS-1:0];

    generate
        genvar i;
        for(i = 0; i<N_CHANNELS; i++)begin
            assign unrolled_data[i] = data_in[i].data;
            assign unrolled_valid[i] = data_in[i].valid;
            assign unrolled_user[i] = data_in[i].user;
        end
    endgenerate


    wire [31:0] selected_data;
    wire [15:0] selected_user;
    wire selected_valid;
    assign selected_data = unrolled_data[write_registers.channel_selector];
    assign selected_user = unrolled_user[write_registers.channel_selector];
    assign selected_valid = unrolled_valid[write_registers.channel_selector];

    initial trigger_out <= 0;

    axi_stream itf_in();
    axi_stream itf_out();
    axi_stream delayed_in();

    assign itf_in.data = selected_data;
    assign itf_in.user = selected_user;
    assign itf_in.valid = selected_valid;

    fp_itf #(
        .FIXED_POINT_Q015(0),
        .INPUT_WIDTH(32)
    ) itof (
        .clock(clock),
        .reset(reset),
        .in(itf_in),
        .out(itf_out)
    );

    register_slice #(
        .DATA_WIDTH(32),
        .DEST_WIDTH(32),
        .USER_WIDTH(32),
        .N_STAGES(3),
        .READY_REG(0)
    ) input_matching_delay (
        .clock(clock),
        .reset(reset),
        .in(itf_in),
        .out(delayed_in)
    );

    axi_stream comp_in_a();
    axi_stream comp_in_b();
    axi_stream comp_out();

    fp_compare #(
        .IEEE_COMPLIANT("FALSE")
    )cmp(
        .clock(clock),
        .in_a(comp_in_a),
        .in_b(comp_in_b),
        .out(comp_out)
    );

    reg [1:0] comp_out_dly;
    wire rising_edge, falling_edge;



    assign rising_edge  = comp_out_dly == 2 && (comp_out.data == 1 || comp_out.data == 0);
    assign falling_edge = (comp_out.data == 1 || comp_out.data == 0) && comp_out_dly == 2;

    always_comb begin
        if(is_axis_float(delayed_in.user))begin
            comp_in_a.data = delayed_in.data;
            comp_in_a.valid = delayed_in.valid;
        end else begin
            comp_in_a.data = itf_out.data;
            comp_in_a.valid = itf_out.valid;
        end
        comp_in_b.data = write_registers.trigger_level;
        comp_in_b.valid = 1;
    end


    reg [15:0] fill_ctr = 0;

    always_ff @(posedge clock) begin
        comp_out_dly <= comp_out.data;
        case (scope_state)
            wait_fill : begin
                if(fill_ctr == MEMORY_DEPTH)begin
                    scope_state <= run;
                end
                fill_ctr <= fill_ctr + 1;
            end
            run : begin
                if(comp_out.valid)begin
                    case (write_registers.trigger_mode)
                        0: begin //RISING EDGE TRIGGER
                            trigger_out <= rising_edge;
                        end
                        1:begin //FALLING EDGE TRIGGER
                            trigger_out <= falling_edge;
                        end 
                        2:begin //BOTH EDGE TRIGGER
                            trigger_out <= rising_edge | falling_edge;
                        end
                    endcase
                end
                if(trigger_out && write_registers.acquisition_mode ==1)begin
                    scope_state <= stop;
                end
                if(write_registers.acquisition_mode == 2)begin
                    scope_state <= free_run;
                end
            end
            stop : begin
                trigger_out <= 0;
                if(rearm_trigger || write_registers.acquisition_mode !=1)begin
                    scope_state <= run;
                end
                if(write_registers.acquisition_mode == 2)begin
                    scope_state <= free_run;
                end
            end
            free_run : begin
                trigger_out <= 1;
                if(write_registers.acquisition_mode !=2)begin
                    scope_state <= run;
                    trigger_out <= 0;
                end
            end
        endcase
    end


endmodule


    /**
       {
        "name": "trigger_engine",
        "type": "parametric_peripheral",
        "registers":[
            {
                "name": "trigger_mode",
                "n_regs": ["1"],
                "description": "Trigger mode selection",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "trigger_level",
                "n_regs": ["1"],
                "description": "Trigger level",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "buffer_addr_low",
                "n_regs": ["1"],
                "description": "Lower 32 bits of the target dma buffer address",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "buffer_addr_high",
                "n_regs": ["1"],
                "description": "Higher 32 bits of the target dma buffer address",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "channel_selector",
                "n_regs": ["1"],
                "description": "Channel used to trigger the scope",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "trigger_point",
                "n_regs": ["1"],
                "description": "Point in the buffer where the trigger will be positioned",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "acquisition_mode",
                "n_regs": ["1"],
                "description": "Acquisition mode selector",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "rearm_trigger",
                "n_regs": ["1"],
                "description": "Rearm the single acquisition trigger upon write and read acquisition status",
                "direction": "RW",
                "fields":[]
            }
            ]
    }  
    **/
