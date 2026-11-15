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

// Self checking testbench for the model of the floating point IP that converts a float to an integer that fcore_fti_ip becomes under Verilator,
// the reference is the C++ compiler.

#include <cmath>
#include <cstdlib>
#include <cstring>
#include <random>
#include <string>
#include <vector>

#include "Vfcore_fti_ip_shim.h"
#include "fp32.hpp"
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

/// What the float to integer conversion does: the float as a signed 32 bit integer, truncated towards zero. A value out
/// of the range saturates and a NaN gives 0, which is an assumption: the emulator does not define these cases
class fcore_fti_model {
public:
    // random words are almost always out of the range of an integer, so values inside it are generated on purpose
    uint32_t generate(std::mt19937_64 &rng) const {
        const uint32_t value = rng();
        switch(rng() % 8){
            case 0:
                return fp32::generate(rng);
            case 1:
            case 2:
                // inside the range, with a fraction when the exponent is small
                return (value & fp32::sign_mask) | ((127 + rng() % 32) << 23) | (value & fp32::mantissa_mask);
            case 3:
                // smaller than one
                return (value & fp32::sign_mask) | ((100 + rng() % 27) << 23) | (value & fp32::mantissa_mask);
            case 4:
                // an integer
                return fp32::to_bits(static_cast<float>(static_cast<int32_t>(rng())));
            case 5:
                // around the ends of the range
                return fp32::to_bits((rng() % 2) ? 2147483648.0f : -2147483648.0f) + static_cast<uint32_t>(rng() % 5) - 2;
            default:
                return value;
        }
    }

    uint32_t reference(uint32_t operand) const {
        const float value = fp32::to_float(operand);
        if(fp32::is_nan(operand)) return 0;
        if(value >= 2147483648.0f) return 0x7FFFFFFF;
        if(value < -2147483648.0f) return 0x80000000;
        return static_cast<uint32_t>(static_cast<int32_t>(value));
    }

    /// Empty when the result is the expected one, otherwise what is wrong with it. The tag is the operand
    std::string compare(const sctb::axis_beat<> &expected, const sctb::axis_beat<> &actual, uint64_t tag) const {
        if(actual.data != expected.data){
            return sctb::format("wrong result: in = %s, out = %s, expected = %s", sctb::hex(tag, 8).c_str(),
                                sctb::hex(actual.data, 8).c_str(), sctb::hex(expected.data, 8).c_str());
        }
        if(!actual.same_sideband(expected)){
            return sctb::format("sideband is not the one of the operand: in = %s, dest/user/tlast = %u/%u/%d, expected %u/%u/%d",
                                sctb::hex(tag, 8).c_str(), actual.dest, actual.user, actual.tlast,
                                expected.dest, expected.user, expected.tlast);
        }
        return {};
    }

    static std::vector<std::string> get_class_names() {
        return {"below one", "fraction truncated", "integer", "positive overflow", "negative overflow", "nan", "minimum"};
    }

    /// Which kind of conversion the operand gives
    size_t classify(uint32_t operand) const {
        const float value = fp32::to_float(operand);
        if(fp32::is_nan(operand)) return 5;
        if(value >= 2147483648.0f) return 3;
        if(value < -2147483648.0f) return 4;
        if(value == -2147483648.0f) return 6;
        if(value > -1.0f && value < 1.0f) return 0;
        return value == std::trunc(value) ? 2 : 1;
    }
};

/// Reset, a stream of random operations, wait for the pipeline to empty, then the checks of the totals.
/// Every operation is put on the input stream and the result it must give is said right after, the scoreboard compares
/// it with what comes out
class fcore_fti_sequence {
public:
    fcore_fti_sequence(const fcore_fti_model &model, sctb::axis_source<> &operand_a, const sctb::clock &clk, sc_signal<bool> &reset,
                   sctb::scoreboard<> &scoreboard, sctb::coverpoint &result_classes, sctb::covergroup &coverage, int64_t n_vectors) :
        model(model), a(operand_a.get_master()), clk(clk), reset(reset), scoreboard(scoreboard), result_classes(result_classes),
        coverage(coverage), n_vectors(n_vectors), rng(1) {}

    void run() {
        sctb::reset_sequence(reset, clk, reset_cycles);

        sctb::progress progress(n_vectors);
        const sc_time start = sc_time_stamp();
        for(int64_t i = 0; i < n_vectors; i++){
            progress.update(i);
            const auto n = static_cast<uint32_t>(i);
            const uint32_t operand = model.generate(rng);

            // the sideband of the result is the one of the operand, the IP has no dest and no tlast
            a.put(operand, n, n + user_offset, (n & 1) != 0);
            clk.wait_cycles(1);

            result_classes.hit(model.classify(operand));
            scoreboard.expect({model.reference(operand), 0, n + user_offset, false}, operand);
        }
        progress.finish();
        sctb::check_throughput(n_vectors, sc_time_stamp() - start, clk);

        a.idle();
        sctb::drain(scoreboard, clk, latency + drain_cycles);
        scoreboard.finish();
        sctb::check_latency(scoreboard, latency);
        coverage.report();
        sctb::reporter::instance().info(sctb::format("%lld vectors checked", static_cast<long long>(scoreboard.get_checked())));
        sctb::finish();
    }

private:
    // two cycles for the conversion to double and one for the integer
    static constexpr int latency = 3;
    static constexpr int reset_cycles = 4;
    static constexpr int drain_cycles = 16;
    static constexpr uint32_t user_offset = 5;

    const fcore_fti_model &model;
    sctb::axis_master<> &a;
    const sctb::clock &clk;
    sc_signal<bool> &reset;
    sctb::scoreboard<> &scoreboard;
    sctb::coverpoint &result_classes;
    sctb::covergroup &coverage;
    int64_t n_vectors;
    std::mt19937_64 rng;
};

int sc_main(int argc, char *argv[]) {
    Verilated::commandArgs(argc, argv);
    sctb::init();

    constexpr int64_t default_vectors = 10000000;
    const sctb::options options(argc, argv);
    const int64_t n_vectors = options.get_positional_integer(0, default_vectors);
    const fcore_fti_model model;

    // the clock and the reset
    sctb::clock clk("clock");
    sc_signal<bool> reset("reset");

    // the device
    Vfcore_fti_ip_shim dut("dut");
    dut.clock(clk.get_signal());
    dut.reset(reset);

    // the stream going in, driven, and the one coming out, answered and watched
    sctb::axis_source<> operand_a("a", clk, 32);
    sctb::axis_sink<> result("result", clk, 32);
    operand_a.connect(dut);
    result.connect(dut);

    // the waveform, written when the command line has --trace=<file>
    sctb::trace trace(options, clk);
    trace.add("reset", reset);
    trace.add(operand_a);
    trace.add(result);

    // the checking: the sequence says what each operation must give, the sink hands what comes out to the scoreboard
    sctb::scoreboard<> scoreboard("fcore_fti_ip", model, &fcore_fti_model::compare, clk.get_period());
    sctb::coverpoint result_classes("result class", model.get_class_names());
    sctb::covergroup coverage;
    coverage.add(result_classes);

    result.add_listener(scoreboard, &sctb::scoreboard<>::observe);

    fcore_fti_sequence sequence(model, operand_a, clk, reset, scoreboard, result_classes, coverage, n_vectors);
    sctb::spawn("sequence", sequence, &fcore_fti_sequence::run);

    const int result_code = sctb::run();
    dut.final();
    return result_code;
}
