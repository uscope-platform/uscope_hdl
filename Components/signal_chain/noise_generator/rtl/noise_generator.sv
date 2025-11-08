`timescale 10ns / 1ns

module noise_generator #(
    OUTPUT_WIDTH = 32,
    parameter GAUSSIAN_OUT = 1,
    parameter LFSR_WIDTH = 21,
    parameter N_PRBS_GENERATORS = 16,
    parameter [LFSR_WIDTH-1:0] INITIAL_STATE [N_PRBS_GENERATORS-1:0] = '{
        21'b000010000000100000001,
        21'b000000010000001000000,
        21'b000010100000000000100,
        21'b000000000110000000000,
        21'b000100000000000001000,
        21'b100000000100010000000,
        21'b000001001110000000000,
        21'b000010000000000010001,
        21'b000000000001000000100,
        21'b000000010000000010000,
        21'b000000100000010000000,
        21'b010000000000000001000,
        21'b100100000000000001100,
        21'b000000000001000100000,
        21'b010010000000000000000,
        21'b000000001010100000000
    },
    N_OUTPUTS = 16,
    FLOAT_OUT = 0
)(
    input wire clock,
    input wire reset,
    input wire trigger,
    output wire active,
    axi_lite.slave axi_in,
    axi_stream.master data_out
);

    localparam N_REGISTERS = 1+N_OUTPUTS;

    reg [31:0] cu_read_registers [N_REGISTERS-1:0];
    reg [31:0] cu_write_registers [N_REGISTERS-1:0];

    axil_simple_register_cu #(
        .N_READ_REGISTERS(N_REGISTERS),
        .N_WRITE_REGISTERS(N_REGISTERS),
        .ADDRESS_MASK('hFF)
    ) CU (
        .clock(clock),
        .reset(reset),
        .input_registers(cu_read_registers),
        .output_registers(cu_write_registers),
        .axil(axi_in)
    );

    axi_stream generator_out();

    generate 
        if(FLOAT_OUT)begin

            fp_itf #(
                .FIXED_POINT_Q015(1),
                .INPUT_WIDTH(16)
            ) itf (
                .clock(clock),
                .reset(reset),
                .in(generator_out),
                .out(data_out)
            );

        end else begin

            assign data_out.user = generator_out.user;
            assign data_out.data = generator_out.data;
            assign data_out.dest = generator_out.dest;
            assign data_out.valid = generator_out.valid;
            assign data_out.tlast = generator_out.tlast;
            assign generator_out.ready = data_out.ready;
        end

    endgenerate



    assign cu_read_registers = cu_write_registers;

    wire [31:0] active_outputs;

    assign active_outputs = cu_write_registers[0];

    wire [31:0] output_dest [N_OUTPUTS-1:0];

    assign active = |active_outputs;


    generate
        for (genvar i = 0; i < N_OUTPUTS; i++) begin
            assign output_dest[i] = cu_write_registers[i+1];
        end
    endgenerate


    localparam polynomial = 'h281000;


    reg [LFSR_WIDTH-1:0] state_reg [N_PRBS_GENERATORS-1:0] = INITIAL_STATE;
    wire [LFSR_WIDTH-1:0] state_out [N_PRBS_GENERATORS-1:0];

    wire [N_PRBS_GENERATORS-1:0] generators_out;

    reg [15:0] gaussian_erf [65535:0];

    initial begin
        $readmemh("erf.mem", gaussian_erf);
    end


    enum reg {
        idle = 0,
        working = 1
    } state = idle;

    reg[7:0] output_counter = 0;

    initial begin
        generator_out.valid = 1'b0;
        generator_out.tlast = 1'b0;
        generator_out.data = 0;
        generator_out.dest = 0;
        generator_out.user = get_axis_metadata(16, 0, 0);
    end
    wire [15:0] noise_gen_out = GAUSSIAN_OUT == 1 ? gaussian_erf[generators_out]: generators_out;
    generate
        genvar i;

        for(i = 0; i < N_PRBS_GENERATORS; i++) begin

            lfsr # (
                .LFSR_WIDTH(21),
                .LFSR_POLY(polynomial),
                .LFSR_CONFIG("FIBONACCI"),
                .LFSR_FEED_FORWARD(0),
                .REVERSE(0),
                .DATA_WIDTH(1),
                .STYLE("AUTO")
            ) source (
                .clock(clock),
                .reset(reset),
                .data_in(1'b0),
                .state_in(state_reg[i]),
                .data_out(generators_out[i]),
                .state_out(state_out[i])
            );

            always_ff@(posedge clock) begin
                generator_out.valid <= 1'b0;
                generator_out.tlast <= 1'b0;
                if(~reset) begin
                    state_reg[i] <= INITIAL_STATE[i];
                end else begin
                    case (state)
                        idle:begin
                            if(trigger & |active_outputs) begin
                                state <= working;
                                output_counter <= 0;
                            end
                        end
                        working: begin
                            if(output_counter == active_outputs-1)begin
                                state <= idle;
                                generator_out.tlast <= 1'b1;
                            end else begin
                                output_counter <= output_counter + 1;
                            end
                            if(generator_out.ready)begin
                                state_reg[i] <= state_out[i];
                                generator_out.data <= {{generator_out.DATA_WIDTH-16{noise_gen_out[15]}}, noise_gen_out};
                                generator_out.dest <= output_dest[output_counter];
                                generator_out.valid <= 1'b1;
                            end
                        end
                    endcase
                end
            end
        end



    endgenerate


endmodule



 /**
    {
        "name": "noise_generator",
        "alias": "noise_generator",
        "type": "parametric_peripheral",
        "registers":[
            {
                "name": "enable",
                "n_regs": ["1"],
                "description": "Write 1 to a bit in this register to enable the corresponding channel",
                "direction": "RW",
                "fields":[]
            },
            {
                "name": "dest_$",
                "n_regs": ["N_OUTPUTS"],
                "description": "Value of the destination field for channel $",
                "direction": "RW",
                "fields":[]
            }
        ]
    }
 **/
