`timescale 10ns / 1ns


module uscope_testing();


    wire logic_clock, IO_clock, reset, dma_done;

    axi_lite control_axi();
    AXI #(.ID_WIDTH(2), .ADDR_WIDTH(32), .DATA_WIDTH(64))  uscope();
    AXI #(.ADDR_WIDTH(32)) fcore_rom_link();
    

    base_zynq #(
        .FCORE_PRESENT(1)
    ) PS (        
        .logic_clock(logic_clock),
        .io_clock(IO_clock),
        .reset(reset),
        .axi_out(control_axi),
        .fcore_axi(fcore_rom_link),
        .scope(uscope),
        .dma_done(dma_done)
    );


    uscope_testing_logic testing_logic (
        .clock(logic_clock),
        .reset(reset),
        .dma_done(dma_done),
        .axi_in(control_axi),
        .scope_out(uscope)
    );
        
endmodule