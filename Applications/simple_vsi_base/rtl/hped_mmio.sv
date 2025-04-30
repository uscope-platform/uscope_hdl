
module hped_mmio #(
    parameter N_DATAPOINTS = 12,
    parameter BASE_ADDRESS = 0
) (
    input wire clock,
    input wire reset,
    axi_stream.slave data_in,
    axi_lite.slave axi_bus
);
    axi_stream write_if();
    axi_stream read_data();
    axi_stream read_addr();

    assign data_in.ready = 1;

    reg [31:0] memory [N_DATAPOINTS-1:0] = '{default:0};
    wire [31:0] read_value;
    assign read_value = memory[read_addr.data];

    always_ff @(posedge clock) begin
        read_addr.ready <= 1;
        read_data.valid <= 0;
        if(data_in.valid)begin
            memory[data_in.dest] <= data_in.data;
        end

        if(read_addr.valid)begin
            read_data.data <= read_value;
            read_data.valid <= 1;
        end
    end

    axil_external_registers_cu #(
        .REGISTERS_WIDTH(32),
        .REGISTERED_BUFFERS(0),
        .BASE_ADDRESS(BASE_ADDRESS),
        .READ_DELAY(0)
    ) bus_interface (
        .clock(clock),
        .reset(reset),
        .read_address(read_addr),
        .read_data(read_data),
        .write_data(write_if),
        .axi_in(axi_bus)
    );


endmodule