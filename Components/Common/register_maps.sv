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

package reg_maps;

      struct { 
        int timebase = 0;
        int chain_0 = 'h100;
        int chain_1 = 'h200;
        int chain_2 = 'h300;
        int chain_3 = 'h400;
        int chain_4 = 'h500;
        int chain_5 = 'h600;
        int chain_6 = 'h700;
        int chain_7 = 'h800;
        int chain_8 = 'h900;
        int chain_9 = 'hA00;
        int chain_10 = 'hB00;
        int chain_11 = 'hC00;
        int chain_12 = 'hD00;
        int chain_13 = 'hE00;
        int chain_14 = 'hF00;
      } pwm_gen_map_regs;

     struct { 
        int tresh_0l = 0;
        int tresh_0h = 'h4;
        int deadtime_0 = 'h8;
        int start = 'hc;
        int stop = 'h10;
        int tb_shift = 'h14;
        int out_en = 'h18;
        int dt_en = 'h1c;
        int control = 'h1c;
     } pwm_chain_1_regs;

     struct { 
        int tresh_0l = 0;
        int tresh_1l = 'h4;
        int tresh_0h = 'h8;
        int tresh_1h = 'hC;
        int deadtime_0 = 'h10;
        int deadtime_1 = 'h14;
        int start = 'h18;
        int stop = 'h1c;
        int tb_shift = 'h20;
        int out_en = 'h24;
        int dt_en = 'h28;
        int control = 'h2c;
     } pwm_chain_2_regs;


     struct { 
        int cmp_low_f = 0;
        int cmp_low_r = 'h4;
        int cmp_high_f = 'h8;
        int cmp_h_r = 'hc;
        int offset_0 = 'h10;
        int shift_0 = 'h14;
        int denoise_tresh_0 = 'h18;
        int control = 'h1C;
        int tap_data = 'h20;
        int tap_address = 'h2C;
     } adc_processing_1_regs;
     
     struct { 
        int cmp_low_f = 0;
        int cmp_low_r = 'h4;
        int cmp_high_f = 'h8;
        int cmp_h_r = 'hc;
        int offset_0 = 'h10;
        int offset_1 = 'h14;
        int offset_2 = 'h18;
        int shift_0 = 'h1c;
        int denoise_tresh_0 = 'h20;
        int denoise_tresh_1 = 'h24;
        int denoise_tresh_2 = 'h38;
        int control = 'h2C;
        int tap_data = 'h30;
        int tap_address = 'h34;
     } adc_processing_3_regs;
     
     struct { 
        int cmp_low_f = 0;
        int cmp_low_r = 'h4;
        int cmp_high_f = 'h8;
        int cmp_h_r = 'hc;
        int offset_0 = 'h10;
        int offset_1 = 'h14;
        int offset_2 = 'h18;
        int offset_3 = 'h1c;
        int offset_4 = 'h20;
        int offset_5 = 'h24;
        int offset_6 = 'h28;
        int offset_7 = 'h2C;
        int offset_8 = 'h30;
        int offset_9 = 'h34;
        int offset_10 = 'h38;
        int offset_11 = 'h3C;
        int shift_0 = 'h40;
        int shift_1 = 'h44;
        int denoise_tresh_0 = 'h48;
        int denoise_tresh_1 = 'h4C;
        int denoise_tresh_2 = 'h50;
        int denoise_tresh_3 = 'h54;
        int denoise_tresh_4 = 'h58;
        int denoise_tresh_5 = 'h5C;
        int denoise_tresh_6 = 'h60;
        int denoise_tresh_7 = 'h64;
        int denoise_tresh_8 = 'h68;
        int denoise_tresh_9 = 'h6C;
        int denoise_tresh_10 = 'h70;
        int denoise_tresh_11 = 'h74;
        int control = 'h78;
        int tap_data = 'h7c;
        int tap_address = 'h80;
     } adc_processing_12_regs;
     
     struct { 
        int n_channels = 0;
        int io_map_addr = 'h4;
        int io_map_data = 'h8;
     } fcore_regs;
     
     struct { 
        int low = 0;
        int high = 'h4;
        int dest = 'h8;
     } axis_constant_regs;
     
     struct { 
        int control = 0;
        int ss_delay = 'h4;
        int period = 'h8;
        int trigger = 'hc;
        int data_0 = 'h10;
    } SPI_regs;

    struct { 
        int enable = 0;
        int period = 'h4;
        int treshold = 'h8;
    } en_gen_regs; 

    struct { 
        int out = 0;
        int in = 'h4;
    } gpio_regs; 

    struct { 
        int control = 0;
        int period = 'h4;
        int duty = 'h8;
        int deadtime = 'hc;
        int ps_0 = 'h10;
        int ps_1 = 'h14;
        int ps_2 = 'h18;
        int ps_3 = 'h1c;
        int ps_4 = 'h20;
        int ps_5 = 'h24;
        int ps_6 = 'h28;
        int ps_7 = 'h2c;
        int ps_8 = 'h30;
        int ps_9 = 'h34;
        int ps_10 = 'h38;
        int ps_11 = 'h3c;
        int d_adj_0 = 'h40;
        int d_adj_1 = 'h44;
        int d_adj_2 = 'h48;
        int d_adj_3 = 'h4c;
        int d_adj_4 = 'h50;
        int d_adj_5 = 'h54;
        int d_adj_6 = 'h58;
        int d_adj_7 = 'h5c;
        int d_adj_8 = 'h60;
        int d_adj_9 = 'h64;
        int d_adj_10 = 'h68;
        int d_adj_11 = 'h6c;
    } pmp_buck_regs;

    struct { 
        int control = 0;
        int period = 'h4;
        int duty_1 = 'h8;
        int duty_2 = 'hc;
        int phase_shift_1 = 'h10;
        int phase_shift_2 = 'h14;
        int deadtime = 'h18;
    } pmp_dab_regs;

    struct { 
        int cl_transition_tresh = 0;
        int input_voltage_addr = 'h4;
        int startup_ramp_inc = 'h8;
        int duty_saturation = 'hc;
        int force_sequencing = 'h10;
        int startup_ramp_div = 'h14;
    } buck_sequencer_regs;

    struct { 
        int sec_start_tresh = 0;
        int startup_done_tresh = 'h4;
        int startup_voltage_addr = 'h8;
        int startup_ramp_inc = 'hc;
        int ps_saturation = 'h10;
        int forced_sequencing = 'h14;
    } dab_sequencer_regs;

    struct { 
        int stop_value = 0;
        int dest = 'h4;
        int inc = 'h8;
        int tb_div = 'hc;
        int ramp_bypass = 'h10;
    } ramp_generator_regs;

    struct { 
        int buffer_size = 0;
        int enable = 'h4;
        int buffer_addr_low = 'h8;
        int buffer_addr_high = 'hc;
        int selected_trigger = 'h10;
        int capture_ack = 'h14;
        int trigger_position = 'h18;
    } uscope_regs;

    struct { 
        int control = 0;
        int tb_divider = 'h4;
        int step_delay = 'h8;
        int order_0 = 'hC;
        int order_1 = 'h10;
        int order_2 = 'h14;
    } prog_sequencer_3_regs;

endpackage

