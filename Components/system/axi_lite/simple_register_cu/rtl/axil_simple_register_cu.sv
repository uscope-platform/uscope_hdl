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
`timescale 10 ns / 1 ns

// input_registers / output_registers are typed by READ_TYPE / WRITE_TYPE, which
// must be given. They can be packed or unpacked structs or arrays, as long as
// every member is a bit-stream type. The register count is
// $bits(type)/REGISTERS_WIDTH. Registers follow declaration order: the first
// declared field/element is register 0 (address 0x0), the next is register 1
// (0x4), and so on. (For an array declared [N-1:0] that means element N-1 is
// register 0; declare it [0:N-1] if you want element i at register i.)
// INITIAL_OUTPUT_VALUES is a WRITE_TYPE value applied on reset (default all 0).
//
// Register access triggers: mark a register by name in TRIGGER_MASK (a value of
// WRITE_TYPE, e.g. '{rearm_status: 1, default: 0}) and it gets one bit on
// trigger_out, pulsed for one cycle when that register is written (reads do not
// trigger). The number of bits equals the number of bits set in the mask (mark
// each register with a single 1), ordered by register address (lowest = bit 0).
// The pulse is in the cycle the new value appears on output_registers.
// Out-of-range writes pulse nothing.
//
// Example:
//   axil_simple_register_cu #(
//       .READ_TYPE (rdc_status_t),
//       .WRITE_TYPE(rdc_registers_t),
//       .INITIAL_OUTPUT_VALUES('{offset: 0, dds_divider: 100, modulator_divider: 8}),
//       .TRIGGER_MASK('{offset: 1, default: 0}),   // trigger_out[0] pulses on a write to offset
//       .ADDRESS_MASK('hFF)
//   ) cu (.input_registers(status), .output_registers(regs), ...);

module axil_simple_register_cu #(
    parameter type READ_TYPE,
    parameter type WRITE_TYPE,
    parameter REGISTERS_WIDTH = 32,
    parameter WRITE_TYPE INITIAL_OUTPUT_VALUES = '{default:'0},
    parameter WRITE_TYPE TRIGGER_MASK = '{default:'0},
    // number of triggers = number of bits set in the mask (mark each register with 1)
    parameter N_TRIGGER_REGISTERS = ($countones(($bits(WRITE_TYPE))'({>>{TRIGGER_MASK}})) > 0) ? $countones(($bits(WRITE_TYPE))'({>>{TRIGGER_MASK}})) : 1,
    parameter REGISTERED_BUFFERS = 0,
    parameter [31:0] ADDRESS_MASK = 0
) (
    input wire clock,
    input wire reset,
    input READ_TYPE input_registers,
    output WRITE_TYPE output_registers,
    output reg [N_TRIGGER_REGISTERS-1:0] trigger_out,   // one bit per register marked in TRIGGER_MASK
    axi_lite.slave axil
);

localparam int NR = $bits(READ_TYPE)  / REGISTERS_WIDTH;
localparam int NW = $bits(WRITE_TYPE) / REGISTERS_WIDTH;

generate
    if ($bits(READ_TYPE) % REGISTERS_WIDTH != 0) begin : g_chk_rd
        $error("READ_TYPE (%0d bits) is not a multiple of REGISTERS_WIDTH (%0d)", $bits(READ_TYPE), REGISTERS_WIDTH);
    end
    if ($bits(WRITE_TYPE) % REGISTERS_WIDTH != 0) begin : g_chk_wr
        $error("WRITE_TYPE (%0d bits) is not a multiple of REGISTERS_WIDTH (%0d)", $bits(WRITE_TYPE), REGISTERS_WIDTH);
    end
endgenerate

// Flat views of the register banks. In a packed type the first field sits in
// the MSBs, so register i is chunk (N-1-i) of the flat vector.
logic [NR*REGISTERS_WIDTH-1:0] read_flat;
logic [NW*REGISTERS_WIDTH-1:0] write_flat;   // register state

// Bit-stream (not plain) assignment so READ_TYPE / WRITE_TYPE can be packed or
// unpacked. {>>{x}} walks x in declaration order, first member/element first.
assign read_flat = {>>{input_registers}};
always_comb begin
    {>>{output_registers}} = write_flat;
end

    // function [REGISTERS_WIDTH-1:0]	apply_strobe;
    //     input [REGISTERS_WIDTH-1:0] prior_data;
    //     input [REGISTERS_WIDTH-1:0] new_data;
    //     input [REGISTERS_WIDTH/8-1:0] strobe;

    //     integer	k;
    //     for(k=0; k<REGISTERS_WIDTH/8; k=k+1)
    //     begin
    //         apply_strobe[k*8 +: 8]
    //             = strobe[k] ? new_data[k*8 +: 8] : prior_data[k*8 +: 8];
    //     end
    // endfunction


// HANDLE READ DATA CHANNEL 

logic read_ready;
logic [31:0] read_data;
logic [31:0] read_address;
logic read_address_valid;

initial axil.RVALID = 0;

always @ (posedge clock) begin
    if (~reset) begin
        axil.RVALID <= 0;
    end else begin
        if (read_ready)begin
            axil.RVALID <= 1'b1;
        end else if (axil.RREADY) begin
            axil.RVALID <= 1'b0;
        end        
    end
end
assign read_ready = read_address_valid && (~axil.RVALID || axil.RREADY);
assign	axil.RDATA = read_data;
assign	axil.RRESP = 2'b00;


// HANDLE READ ADDRESS CHANNEL

axil_skid_buffer #(
    .REGISTER_OUTPUT(REGISTERED_BUFFERS),
    .DATA_WIDTH(32)
) address_read_buffer (
    .clock(clock),
    .reset(reset),
    .in_valid(axil.ARVALID),
    .in_ready(axil.ARREADY),
    .in_data(axil.ARADDR),
    .out_valid(read_address_valid),
    .out_ready(read_ready),
    .out_data(read_address)
);

// HANDLE BRESP CHANNEL

logic write_ready;
initial axil.BVALID = 0;

always @ (posedge clock) begin
    if (~reset) begin
        axil.BVALID <= 0;
    end else begin
        if (write_ready)begin
            axil.BVALID <= 1'b1;
        end else if (axil.BREADY) begin
            axil.BVALID <= 1'b0;
        end  
    end
end

assign	axil.BRESP = 2'b00;


// HANDLE WRITE DATA AND WRITE ADDRESS CHANNEL

logic write_valid;
logic [31:0] write_data;
logic [31:0] write_address;

logic write_address_valid;

axil_skid_buffer #(
    .REGISTER_OUTPUT(REGISTERED_BUFFERS),
    .DATA_WIDTH(32)
) address_write_buffer (
    .clock(clock),
    .reset(reset),
    .in_valid(axil.AWVALID),
    .in_ready(axil.AWREADY),
    .in_data(axil.AWADDR),
    .out_valid(write_address_valid),
    .out_ready(write_ready),
    .out_data(write_address)
);

logic [3:0] write_strobe;
logic write_data_valid;

axil_skid_buffer #(
    .REGISTER_OUTPUT(REGISTERED_BUFFERS),
    .DATA_WIDTH(32+4)
) write_data_buffer (
    .clock(clock),
    .reset(reset),
    .in_valid(axil.WVALID),
    .in_ready(axil.WREADY),
    .in_data({axil.WDATA, axil.WSTRB}),
    .out_valid(write_data_valid),
    .out_ready(write_ready),
    .out_data({write_data, write_strobe})
);

assign write_ready = write_valid && (~axil.BVALID || axil.BREADY);
assign write_valid = write_data_valid && write_address_valid;


wire [31:0] register_read_address;
wire [31:0] register_write_address;

assign register_read_address = (read_address & ADDRESS_MASK) >> 2;
assign register_write_address = (write_address & ADDRESS_MASK) >> 2;


always @ (posedge clock) begin
    if (~reset) begin
        read_data <= 0;
    end else begin
        if(read_address_valid) begin
            if (register_read_address < NR)
                read_data <= read_flat[(NR-1-register_read_address)*REGISTERS_WIDTH +: REGISTERS_WIDTH];
            else
                read_data <= 0;
        end
    end
end



always_ff @(posedge clock) begin
    if (~reset) begin
        write_flat <= {>>{INITIAL_OUTPUT_VALUES}};
    end else begin
        if(write_valid & write_ready) begin
            if (register_write_address < NW)
                write_flat[(NW-1-register_write_address)*REGISTERS_WIDTH +: REGISTERS_WIDTH] <= write_data;
        end
    end
end


// Register access triggers. A register is a trigger if its chunk in the mask
// is non-zero; trigger bits are assigned in register order. Everything here is
// constant after unrolling.
localparam logic [NW*REGISTERS_WIDTH-1:0] MASK_FLAT = {>>{TRIGGER_MASK}};

function automatic int count_marked(input logic [NW*REGISTERS_WIDTH-1:0] mask);
    int c = 0;
    for (int i = 0; i < NW; i++)
        if (|mask[(NW-1-i)*REGISTERS_WIDTH +: REGISTERS_WIDTH]) c++;
    return c;
endfunction

generate
    if (count_marked(MASK_FLAT) > N_TRIGGER_REGISTERS) begin : g_chk_trig
        $error("TRIGGER_MASK marks %0d registers but N_TRIGGER_REGISTERS is %0d",
               count_marked(MASK_FLAT), N_TRIGGER_REGISTERS);
    end
endgenerate

wire write_access = write_valid && write_ready;

always_ff @(posedge clock) begin
    int k;
    trigger_out <= '0;
    k = 0;
    for (int i = 0; i < NW; i++) begin
        if (|MASK_FLAT[(NW-1-i)*REGISTERS_WIDTH +: REGISTERS_WIDTH]) begin
            if (reset && k < N_TRIGGER_REGISTERS &&
                write_access && register_write_address == i)
                trigger_out[k] <= 1'b1;
            k++;
        end
    end
end

endmodule