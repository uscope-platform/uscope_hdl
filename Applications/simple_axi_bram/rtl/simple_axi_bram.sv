`timescale 10ns / 1ns

module simple_axi_bram ();



    wire clock, reset, slow_clock, dma_done;
    
    axi_lite control_axi();
    AXI fcore();
    axi_lite dma_axi();
    axi_stream uscope();

    Zynq_axis_wrapper #(
        .FCORE_PRESENT(0)
    ) TEST(        
        .Logic_Clock(clock),
        .IO_clock(slow_clock),
        .Reset(reset),
        .axi_out(control_axi),
        .dma_axi(dma_axi),
        .fcore_axi(fcore),
        .scope(uscope),
        .dma_done(dma_done)
    );

    localparam AXI_BASE = 32'h43C00000;

    axi_lite #(.INTERFACE_NAME("AXI")) axi();

    axil_crossbar_interface #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(32),
        .NM(1),
        .NS(1),
        .SLAVE_ADDR('{AXI_BASE}),
        .SLAVE_MASK('{32'h0f000})
    ) axi_xbar (
        .clock(clock),
        .reset(reset),
        .slaves('{control_axi}),
        .masters('{axi})
    );

    logic [31:0] i_registers [2:0];
    logic [31:0] o_registers [2:0];


    axil_simple_register_cu #(
        .N_READ_REGISTERS(3),
        .N_WRITE_REGISTERS(3),
        .ADDRESS_MASK('hf)
    ) UUT (
        .clock(clock),
        .reset(reset),
        .input_registers(i_registers),
        .output_registers(o_registers),
        .axil(axi)
    );

    always_comb begin
        i_registers[0] <= o_registers[0];
        i_registers[1] <= o_registers[1];
        i_registers[2] <= o_registers[2];
    end


endmodule