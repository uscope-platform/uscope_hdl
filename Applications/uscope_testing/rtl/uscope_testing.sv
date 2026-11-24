`timescale 10ns / 1ns


module uscope_testing();

    localparam ARCH = "ZYNQMP";
    localparam AXI_ADDR_WIDTH = ARCH == "ZYNQMP" ? 49: 32;
    localparam AXI_DATA_WIDTH = ARCH == "ZYNQMP" ? 128: 64;
    typedef logic[AXI_ADDR_WIDTH-1:0] axi_address_t;
    
    wire logic_clock, IO_clock, reset, dma_done;

    axi_lite control_axi();
    AXI #(.ID_WIDTH(2), .ADDR_WIDTH(AXI_ADDR_WIDTH), .DATA_WIDTH(AXI_DATA_WIDTH))  uscope();
    AXI #(.ADDR_WIDTH(AXI_ADDR_WIDTH)) fcore_rom_link();

    localparam axi_address_t BASE_ADDRESS = ARCH == "ZYNQMP" ? 'h443c00000: 'h43c00000;

    generate
    if(ARCH == "ZYNQMP") begin
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
    end else begin
        base_zynqmp #(
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
    end
    endgenerate;


    uscope_testing_logic #(
        .axi_address_t(axi_address_t),
        .BASE_ADDRESS(BASE_ADDRESS)
    )testing_logic (
        .clock(logic_clock),
        .reset(reset),
        .dma_done(dma_done),
        .axi_in(control_axi),
        .scope_out(uscope)
    );
        
endmodule