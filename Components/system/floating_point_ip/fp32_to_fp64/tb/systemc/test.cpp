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

// Self checking testbench for fp_fp32_to_fp64, the reference is the conversion of the C++ compiler

#include <cstdlib>
#include <cstring>
#include <random>
#include <string>
#include <vector>

#include "Vfp_fp32_to_fp64_shim.h"
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

class fp32_to_fp64_model {
public:

    // random words are almost never denormal, infinite or NaN, so those are generated on purpose
    uint64_t generate(std::mt19937_64 &rng) const {
        uint32_t value = rng();
        switch(rng() % 8){
            case 0:
            case 1:
                // zero or denormal, with every position of the leading one
                return (value & sign_mask) | ((value & mantissa_mask) >> (rng() % 23));
            case 2:
                // infinity or NaN
                value |= exponent_mask;
                return rng() % 2 ? value & ~mantissa_mask : value;
            case 3:
                // the edges of the normal range
                return (value & ~exponent_mask) | ((rng() % 2 ? 0x01u : 0xFEu) << 23);
            default:
                return value;
        }
    }

    uint64_t reference(uint64_t input) const {
        const uint32_t bits = input;
        float single;
        std::memcpy(&single, &bits, sizeof(single));
        const double widened = single;
        uint64_t result;
        std::memcpy(&result, &widened, sizeof(result));
        return result;
    }

    // a NaN only has to stay a NaN, its payload is not checked
    bool matches(uint64_t got, uint64_t expected) const {
        if(is_nan(expected)) return is_nan(got);
        return got == expected;
    }

    std::vector<std::string> get_class_names() const {return {"zero", "denormal", "normal", "infinity", "nan"};}

    size_t classify(uint64_t input) const {
        const uint32_t exponent = input & exponent_mask;
        const uint32_t mantissa = input & mantissa_mask;
        if(exponent == 0) return mantissa == 0 ? 0 : 1;
        if(exponent == exponent_mask) return mantissa == 0 ? 3 : 4;
        return 2;
    }

    /// Empty when the result is the expected one, otherwise what is wrong with it
    std::string compare(const sctb::axis_beat<> &expected, const sctb::axis_beat<> &actual, uint64_t input) const {
        if(!matches(actual.data, expected.data)){
            return sctb::format("wrong result: in = %s, out = %s, expected = %s", sctb::hex(input, 8).c_str(),
                                sctb::hex(actual.data, 16).c_str(), sctb::hex(expected.data, 16).c_str());
        }
        if(!actual.same_sideband(expected)){
            return sctb::format("metadata not carried through: in = %s, dest/user/tlast = %u/%u/%d, expected %u/%u/%d",
                                sctb::hex(input, 8).c_str(), actual.dest, actual.user, actual.tlast,
                                expected.dest, expected.user, expected.tlast);
        }
        return {};
    }

private:
    static constexpr uint32_t sign_mask = 0x80000000;
    static constexpr uint32_t exponent_mask = 0x7F800000;
    static constexpr uint32_t mantissa_mask = 0x007FFFFF;

    // the expected value is a double
    static bool is_nan(uint64_t double_bits) {
        return (double_bits & 0x7FF0000000000000) == 0x7FF0000000000000 && (double_bits & 0x000FFFFFFFFFFFFF) != 0;
    }
};

/// Reset, a stream of random inputs, wait for the pipeline to empty, then the checks of the totals.
/// Every input is sent and the result it must give is said right after, the scoreboard compares it with what comes out
class fp32_to_fp64_sequence {
public:
    fp32_to_fp64_sequence(const fp32_to_fp64_model &model, sctb::axis_source<> &input, const sctb::clock &clk, sc_signal<bool> &reset,
                    sctb::scoreboard<> &scoreboard, sctb::coverpoint &input_classes, sctb::covergroup &coverage, int64_t n_vectors) :
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

    const fp32_to_fp64_model &model;
    sctb::axis_master<> &master;
    const sctb::clock &clk;
    sc_signal<bool> &reset;
    sctb::scoreboard<> &scoreboard;
    sctb::coverpoint &input_classes;
    sctb::covergroup &coverage;
    int64_t n_vectors;
    std::mt19937_64 rng;
};

int sc_main(int argc, char *argv[]) {
    Verilated::commandArgs(argc, argv);
    sctb::init();

    constexpr int64_t default_vectors = 1000000;
    const sctb::options options(argc, argv);
    const int64_t n_vectors = options.get_positional_integer(0, default_vectors);
    const fp32_to_fp64_model model;

    // the clock and the reset
    sctb::clock clk("clock");
    sc_signal<bool> reset("reset");

    // the device
    Vfp_fp32_to_fp64_shim dut("dut");
    dut.clock(clk.get_signal());
    dut.reset(reset);

    // the stream going in, driven and watched, and the one coming out, answered and watched
    sctb::axis_source<> input("in", clk, 32);
    sctb::axis_sink<> output("out", clk, 64);
    input.connect(dut);
    output.connect(dut);

    // the waveform, written when the command line has --trace=<file>
    sctb::trace trace(options, clk);
    trace.add("reset", reset);
    trace.add(input);
    trace.add(output);

    // the checking: the sequence says what each input must give, the sink hands what comes out to the scoreboard
    sctb::scoreboard<> scoreboard("fp32_to_fp64", model, &fp32_to_fp64_model::compare, clk.get_period());
    sctb::coverpoint input_classes("input class", model.get_class_names());
    sctb::covergroup coverage;
    coverage.add(input_classes);

    output.add_listener(scoreboard, &sctb::scoreboard<>::observe);

    fp32_to_fp64_sequence sequence(model, input, clk, reset, scoreboard, input_classes, coverage, n_vectors);
    sctb::spawn("sequence", sequence, &fp32_to_fp64_sequence::run);

    const int result = sctb::run();
    dut.final();
    return result;
}
