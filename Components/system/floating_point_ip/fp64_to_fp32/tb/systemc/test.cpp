//  Copyright 2026 University of Nottingham
//  Author: Filippo Savi <filssavi@gmail.com>
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

// Self checking testbench for fp_fp64_to_fp32, the reference is the conversion of the C++ compiler.
// Results too small for a normal single precision number are flushed to zero, like the core does

#include <cstdlib>
#include <cstring>
#include <random>
#include <string>
#include <vector>

#include "Vfp_fp64_to_fp32_shim.h"
#include "sctb/axis.hpp"
#include "sctb/checks.hpp"
#include "sctb/clocking.hpp"
#include "sctb/coverage.hpp"
#include "sctb/options.hpp"
#include "sctb/progress.hpp"
#include "sctb/report.hpp"
#include "sctb/run.hpp"
#include "sctb/scoreboard.hpp"
#include "sctb/trace.hpp"

class fp64_to_fp32_model {
public:

    // mostly exponents around the single precision range, so overflow and underflow are hit often,
    // and mantissas on the rounding boundaries, so every rounding case is hit
    uint64_t generate(std::mt19937_64 &rng) const {
        uint64_t value = rng();
        switch(rng() % 8){
            case 0:
            case 1:
            case 2:
                value = (value & ~exponent_mask) | ((bias_difference + rng() % 261 - 2) << 52);
                break;
            case 3:
                // infinity or NaN
                value |= exponent_mask;
                if(rng() % 2) value &= ~mantissa_mask;
                break;
            case 4:
                // zero or denormal
                value &= ~exponent_mask;
                break;
            default:
                break;
        }

        // the 29 bits of the mantissa that are rounded away: the first is the guard bit, the others make the sticky bit
        constexpr uint64_t discarded_mask = 0x1FFFFFFF;
        constexpr uint64_t guard_bit = 0x10000000;
        switch(rng() % 6){
            case 0:
                // exact tie
                return (value & ~discarded_mask) | guard_bit;
            case 1:
                // just above the tie
                return (value & ~discarded_mask) | (guard_bit + 1);
            case 2:
                // just below the tie
                return (value & ~discarded_mask) | (guard_bit - 1);
            case 3:
                // rounds up into the next exponent
                return (value & ~mantissa_mask) | (0x7FFFFFull << 29) | guard_bit | (rng() % 2);
            default:
                return value;
        }
    }

    // round to nearest even, anything too big becomes infinity
    uint64_t reference(uint64_t input) const {
        double wide;
        std::memcpy(&wide, &input, sizeof(wide));
        const float single = static_cast<float>(wide);
        uint32_t result;
        std::memcpy(&result, &single, sizeof(result));
        // denormal results are flushed
        if((result & 0x7F800000) == 0) result &= 0x80000000;
        return result;
    }

    // a NaN only has to stay a NaN, its payload is not checked
    bool matches(uint64_t got, uint64_t expected) const {
        if(is_nan(expected)) return is_nan(got);
        return got == expected;
    }

    std::vector<std::string> get_class_names() const {
        return {"zero", "underflow", "normal", "overflow", "infinity", "nan"};
    }

    size_t classify(uint64_t input) const {
        const uint64_t exponent = (input & exponent_mask) >> 52;
        const uint64_t mantissa = input & mantissa_mask;
        if(exponent == 0x7FF) return mantissa == 0 ? 4 : 5;
        if(exponent == 0) return 0;
        if(exponent <= bias_difference) return 1;
        if(exponent > bias_difference + 254) return 3;
        return 2;
    }

    /// Empty when the result is the expected one, otherwise what is wrong with it
    std::string compare(const sctb::axis_beat<> &expected, const sctb::axis_beat<> &actual, uint64_t input) const {
        if(!matches(actual.data, expected.data)){
            return sctb::format("wrong result: in = %s, out = %s, expected = %s", sctb::hex(input, 16).c_str(),
                                sctb::hex(actual.data, 8).c_str(), sctb::hex(expected.data, 8).c_str());
        }
        if(!actual.same_sideband(expected)){
            return sctb::format("metadata not carried through: in = %s, dest/user/tlast = %u/%u/%d, expected %u/%u/%d",
                                sctb::hex(input, 16).c_str(), actual.dest, actual.user, actual.tlast,
                                expected.dest, expected.user, expected.tlast);
        }
        return {};
    }

private:
    static constexpr uint64_t exponent_mask = 0x7FF0000000000000;
    static constexpr uint64_t mantissa_mask = 0x000FFFFFFFFFFFFF;
    // the exponent bias goes from 1023 to 127
    static constexpr uint64_t bias_difference = 896;

    // the expected value is a float, the one got is too
    static bool is_nan(uint64_t single_bits) {
        return (single_bits & 0x7F800000) == 0x7F800000 && (single_bits & 0x007FFFFF) != 0;
    }
};

/// Reset, a stream of random inputs, wait for the pipeline to empty, then the checks of the totals.
/// Every input is sent and the result it must give is said right after, the scoreboard compares it with what comes out
class fp64_to_fp32_sequence {
public:
    fp64_to_fp32_sequence(const fp64_to_fp32_model &model, sctb::axis_source<> &input, const sctb::clock &clk, sc_signal<bool> &reset,
                    sctb::scoreboard<sctb::axis_beat<>> &scoreboard, sctb::coverpoint &input_classes, sctb::covergroup &coverage, int64_t n_vectors) :
        model(model), master(input.get_master()), clk(clk), reset(reset), scoreboard(scoreboard), input_classes(input_classes), coverage(coverage), n_vectors(n_vectors), rng(1) {}

    void run() {
        sctb::reset_sequence(reset, clk, reset_cycles);

        sctb::progress progress(n_vectors);
        const sc_time start = sc_time_stamp();
        for(int64_t i = 0; i < n_vectors; i++){
            progress.update(i);
            const auto n = static_cast<uint32_t>(i);
            const sctb::axis_beat<> beat = {model.generate(rng), n, n + user_offset, (n & 1) != 0};
            master.write(beat);
            input_classes.hit(model.classify(beat.data));
            scoreboard.expect({model.reference(beat.data), beat.dest, beat.user, beat.tlast}, beat.data);
        }
        progress.finish();
        sctb::check_throughput(n_vectors, sc_time_stamp() - start, clk);

        master.idle();
        sctb::drain(scoreboard, clk, latency + drain_cycles);
        scoreboard.finish();
        sctb::check_latency(scoreboard, latency);
        coverage.report();
        sctb::reporter::instance().info(sctb::format("%lld vectors checked", static_cast<long long>(scoreboard.get_checked())));
        sctb::finish();
    }

private:
    static constexpr int latency = 2;
    static constexpr int reset_cycles = 4;
    static constexpr int drain_cycles = 16;
    // dest, user and tlast are not part of the conversion, they have to come out as they went in
    static constexpr uint32_t user_offset = 5;

    const fp64_to_fp32_model &model;
    sctb::axis_master<> &master;
    const sctb::clock &clk;
    sc_signal<bool> &reset;
    sctb::scoreboard<sctb::axis_beat<>> &scoreboard;
    sctb::coverpoint &input_classes;
    sctb::covergroup &coverage;
    int64_t n_vectors;
    std::mt19937_64 rng;
};

int sc_main(int argc, char *argv[]) {
    Verilated::commandArgs(argc, argv);
    sctb::init();

    constexpr int64_t default_vectors = 100000000;
    const sctb::options options(argc, argv);
    const int64_t n_vectors = options.get_positional_integer(0, default_vectors);
    const fp64_to_fp32_model model;

    // the clock and the reset
    sctb::clock clk("clock");
    sc_signal<bool> reset("reset");

    // the device
    Vfp_fp64_to_fp32_shim dut("dut");
    dut.clock(clk.get_signal());
    dut.reset(reset);

    // the stream going in, driven and watched, and the one coming out, answered and watched
    sctb::axis_source<> input("in", clk, 64);
    sctb::axis_sink<> output("out", clk, 32);
    input.connect(dut);
    output.connect(dut);

    // the waveform, written when the command line has --trace=<file>
    sctb::trace trace(options, clk);
    trace.add("reset", reset);
    trace.add(input);
    trace.add(output);

    // the checking: the sequence says what each input must give, the sink hands what comes out to the scoreboard
    sctb::scoreboard<sctb::axis_beat<>> scoreboard("fp64_to_fp32", model, &fp64_to_fp32_model::compare, clk.get_period());
    sctb::coverpoint input_classes("input class", model.get_class_names());
    sctb::covergroup coverage;
    coverage.add(input_classes);

    output.add_listener(scoreboard, &sctb::scoreboard<sctb::axis_beat<>>::observe);

    fp64_to_fp32_sequence sequence(model, input, clk, reset, scoreboard, input_classes, coverage, n_vectors);
    sctb::spawn("sequence", sequence, &fp64_to_fp32_sequence::run);

    const int result = sctb::run();
    dut.final();
    return result;
}
