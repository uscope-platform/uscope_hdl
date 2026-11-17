

package adc_processing_types;

    // NOTE: packed struct fields are laid out MSB first. Across the register
    // file the first declared member maps to the lowest register address (0x00);
    // inside a 32-bit word the first declared field maps to the highest bit
    // positions, i.e. positions are counted down from [31:16] to [15:0].

    typedef struct packed {
        reg signed [15:0] low_falling;    // @0x00 [31:16]
        reg signed [15:0] low_rising;     // @0x00 [15:0]
        reg signed [15:0] high_falling;   // @0x04 [31:16]
        reg signed [15:0] high_rising;    // @0x04 [15:0]
    } comparator_tresholds_register;

    typedef struct packed {
        comparator_tresholds_register slow;   // 0x00-0x04
        comparator_tresholds_register fast;   // 0x08-0x0c
    } comparators;

    typedef struct packed {
        reg signed [15:0] negative;   // [31:16]
        reg signed [15:0] positive;   // [15:0]
    } denoise_tresholds;

    typedef struct packed {
        reg [3:0] shift;            // [31:28]
        reg signed [27:0] offset;   // [27:0]
    } calibrator_coefficients;

    typedef struct packed {
        bit slow;
        bit fast;
    } comparator_control_signal;

    typedef struct packed {
        reg [7:0] decimation_ratio;     // [31:24]
        reg [7:0] n_taps;               // [23:16]
        reg [7:0] slow_fault_threshold; // [15:8]
        reg       linearizer_enable;    // [7]
        reg       disable_fault;        // [6]
        reg       clear_fault;          // [5]
        comparator_control_signal clear_latch; // [4:3]
        comparator_control_signal latch_mode;  // [2:1]
        reg       shift_enable;         // [0]
    } control_register;


endpackage