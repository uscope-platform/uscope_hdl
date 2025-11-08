`timescale 10ns / 1ns
`include "axis_BFM.svh"
`include "axi_lite_BFM.svh"
`include "axi_full_bfm.svh"


module hped_base_tb();

    reg clk, reset;

    parameter PWM_BASE_ADDR = 'hA0000000;
    parameter GPIO_BASE_ADDR = 'hA0010000;
    parameter PHASE_TB = 'hA0020000;
    parameter PHASE_SPI = 'hA0040000;
    parameter PHASE_PROCESSING = 'hA0040000;
    parameter DC_TB = 'hA0030000;
    parameter DC_SPI = 'hA0050000;
    parameter DC_PROCESSING = 'hA0050000;
    parameter ENCODER_IF = 'hA0080000;
    parameter ENCODER_TB = 'hA0090000;
    parameter MMIO_TB = 'hA00A0000;
    parameter IRQC = 'hA00B0000;



    parameter dc_v_base = 150;
    parameter dc_i_base = 300;

    always begin
     clk = 1'b1;
     #0.5 clk = 1'b0;
     #0.5;
    end

    axi_lite axi_master();
    axi_lite mmio_axi();
    AXI data_axi();

    wire dc_clk, dc_ss;
    reg v_data, i_data;

    

    task dc_adc_write_data;
        input logic [13:0] dcv;
        input logic [13:0] dci;
    begin
        @(negedge dc_ss);
        for(integer i = 13; i>=0; i--)begin
            @(posedge dc_clk);
            v_data = dcv[i];
            i_data = dci[i];
        end
    end
    endtask

    reg [31:0] dc_v_current;
    reg [31:0] dc_i_current;

    initial begin
        v_data = 0;
        i_data = 0;
        forever begin
            dc_v_current = dc_v_base + $urandom_range(0, 50);
            dc_i_current = dc_i_base + $urandom_range(0, 50);
            dc_adc_write_data(dc_v_current, dc_i_current);
        end
    end




    wire out_clk, out_ss;
    reg out_v_a, out_v_b, out_v_c;
    reg out_i_a, out_i_b, out_i_c;

    task ac_adc_write_data;
        input logic [13:0] v_a;
        input logic [13:0] v_b;
        input logic [13:0] v_c;
        input logic [13:0] i_a;
        input logic [13:0] i_b;
        input logic [13:0] i_c;
    begin
        @(negedge out_ss);
        for(integer i = 13; i>=0; i--)begin
            @(posedge out_clk);
            out_v_a = v_a[i];
            out_v_b = v_b[i];
            out_v_c = v_c[i];

            out_i_a = i_a[i];
            out_i_b = i_b[i];
            out_i_c = i_c[i];
        end
    end
    endtask

    reg [31:0] out_va_current;
    reg [31:0] out_vb_current;
    reg [31:0] out_vc_current;
    reg [31:0] out_ia_current;
    reg [31:0] out_ib_current;
    reg [31:0] out_ic_current;

    initial begin
        v_data = 0;
        i_data = 0;
        forever begin
            out_va_current = dc_v_base + $urandom_range(0, 50);
            out_vb_current = dc_v_base + $urandom_range(0, 250);
            out_vc_current = dc_v_base + $urandom_range(0, 450);
            out_ia_current = dc_i_base + $urandom_range(0, 50);
            out_ib_current = dc_i_base + $urandom_range(0, 250);
            out_ic_current = dc_i_base + $urandom_range(0, 450);
            ac_adc_write_data(
                out_va_current,
                out_vb_current,
                out_vc_current,
                out_ia_current,
                out_ib_current,
                out_ic_current
            );
        end
    end

    reg a,b,z;
    
    initial begin
        a = 0;
        forever begin
            #14 a = 1;
            #14 a = 0;
        end
    end

    initial begin
        a = 0; 
        #7;
        forever begin
            #14 b = 1;
            #14 b = 0;   
        end
    end

    initial begin
        z=0;
        #(28*200);
        forever begin
            z <= 1;
            #5;
            z <= 0;
            #(1202*7-5);
            
        end
    end


    axi_lite_BFM axil_bfm;

    hped_drive_logic uut(
        .clock(clk),
        .reset(reset),
        .data_axi(data_axi),
        .control_axi(axi_master),
        .dc_spi_clk(dc_clk),
        .dc_spi_cs(dc_ss),
        .dc_spi_data_v(v_data),
        .dc_spi_data_i(i_data),

        .ph_spi_clk(out_clk),
        .ph_spi_cs(out_ss),
        .ph_spi_data_v_a(out_v_a),
        .ph_spi_data_v_b(out_v_b),
        .ph_spi_data_v_c(out_v_c),
        .ph_spi_data_i_a(out_i_a),
        .ph_spi_data_i_b(out_i_b),
        .ph_spi_data_i_c(out_i_c),

        .encoder_a(a),
        .encoder_b(b),
        .encoder_index(z)
    );

    event cfg_done;

    initial begin  
        axil_bfm = new(axi_master,  1);

        //Initial status
        reset <=1'h1;
        #10 reset <=1'h0;
        //TESTS
        #20.5 reset <=1'h1;

        // PWM

        #10 axil_bfm.write(PWM_BASE_ADDR + reg_maps::pwm_gen_map_regs.chain_0 + reg_maps::pwm_chain_3_regs.tresh_0l,      350);
        #10 axil_bfm.write(PWM_BASE_ADDR + reg_maps::pwm_gen_map_regs.chain_0 + reg_maps::pwm_chain_3_regs.tresh_1l,      400);
        #10 axil_bfm.write(PWM_BASE_ADDR + reg_maps::pwm_gen_map_regs.chain_0 + reg_maps::pwm_chain_3_regs.tresh_2l,      450);

        #10 axil_bfm.write(PWM_BASE_ADDR + reg_maps::pwm_gen_map_regs.chain_0 + reg_maps::pwm_chain_3_regs.tresh_0h,      650);
        #10 axil_bfm.write(PWM_BASE_ADDR + reg_maps::pwm_gen_map_regs.chain_0 + reg_maps::pwm_chain_3_regs.tresh_1h,      600);
        #10 axil_bfm.write(PWM_BASE_ADDR + reg_maps::pwm_gen_map_regs.chain_0 + reg_maps::pwm_chain_3_regs.tresh_2h,      550);

        #10 axil_bfm.write(PWM_BASE_ADDR + reg_maps::pwm_gen_map_regs.chain_0 + reg_maps::pwm_chain_3_regs.deadtime_0,    0);
        #10 axil_bfm.write(PWM_BASE_ADDR + reg_maps::pwm_gen_map_regs.chain_0 + reg_maps::pwm_chain_3_regs.deadtime_1,    0);
        #10 axil_bfm.write(PWM_BASE_ADDR + reg_maps::pwm_gen_map_regs.chain_0 + reg_maps::pwm_chain_3_regs.deadtime_2,    0);

        #10 axil_bfm.write(PWM_BASE_ADDR + reg_maps::pwm_gen_map_regs.chain_0 + reg_maps::pwm_chain_3_regs.start,         0);
        #10 axil_bfm.write(PWM_BASE_ADDR + reg_maps::pwm_gen_map_regs.chain_0 + reg_maps::pwm_chain_3_regs.stop,          1000);
        
        #10 axil_bfm.write(PWM_BASE_ADDR + reg_maps::pwm_gen_map_regs.chain_0 + reg_maps::pwm_chain_3_regs.tb_shift, 0);
        #10 axil_bfm.write(PWM_BASE_ADDR + reg_maps::pwm_gen_map_regs.chain_0 + reg_maps::pwm_chain_3_regs.out_en,   'h3F);
        #10 axil_bfm.write(PWM_BASE_ADDR + reg_maps::pwm_gen_map_regs.chain_0 + reg_maps::pwm_chain_3_regs.dt_en,    0);

        #10 axil_bfm.write(PWM_BASE_ADDR + reg_maps::pwm_gen_map_regs.chain_0 + reg_maps::pwm_chain_3_regs.control,  1);

        #10 axil_bfm.write(PWM_BASE_ADDR + reg_maps::pwm_gen_map_regs.sync_select, 0);    
        #10 axil_bfm.write(PWM_BASE_ADDR + reg_maps::pwm_gen_map_regs.sync_delay, 50);
        
        #10 axil_bfm.write(PWM_BASE_ADDR + reg_maps::pwm_gen_map_regs.timebase, 'h28);

        // DC SENSING 

        #10 axil_bfm.write(DC_TB + reg_maps::en_gen_regs.enable,  1);
        #10 axil_bfm.write(DC_TB + reg_maps::en_gen_regs.period,  200);
        #10 axil_bfm.write(DC_TB + reg_maps::en_gen_regs.treshold,   100);

        #10 axil_bfm.write(DC_SPI + reg_maps::SPI_regs.control, 'h1e184);


        #10 axil_bfm.write(PHASE_TB + reg_maps::en_gen_regs.enable,  1);
        #10 axil_bfm.write(PHASE_TB + reg_maps::en_gen_regs.period,  200);
        #10 axil_bfm.write(PHASE_TB + reg_maps::en_gen_regs.treshold,   100);

        #10 axil_bfm.write(PHASE_SPI + reg_maps::SPI_regs.control, 'h1e184);

        #10 axil_bfm.write(ENCODER_TB + reg_maps::en_gen_2_regs.enable,  1);
        #10 axil_bfm.write(ENCODER_TB + reg_maps::en_gen_2_regs.period,  1200);
        #10 axil_bfm.write(ENCODER_TB + reg_maps::en_gen_2_regs.treshold_1,   400);
        #10 axil_bfm.write(ENCODER_TB + reg_maps::en_gen_2_regs.treshold_2,   400);

        #10 axil_bfm.write(ENCODER_IF + reg_maps::encoder_if.angle_dest,  0);
        #10 axil_bfm.write(ENCODER_IF + reg_maps::encoder_if.speed_dest,  1);


        #10 axil_bfm.write(GPIO_BASE_ADDR,  9);
        #10 axil_bfm.write(GPIO_BASE_ADDR,  0);

        #10 axil_bfm.write(IRQC,  1);
        ->cfg_done;
    end




    reg [31:0] mmio_repeated [17:0];
    reg [31:0] read_result;
    reg [31:0] read_addr;

    initial begin
        @(cfg_done);
        read_addr = 0;
        forever begin
            #500;
            axil_bfm.read(MMIO_TB + read_addr*4, read_result);
            mmio_repeated[read_addr] = read_result;
            read_addr = $urandom_range(0,17);
        end
    end

endmodule