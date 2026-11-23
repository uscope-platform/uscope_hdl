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

// Self checking testbench for the model of the floating point reciprocal IP that fcore_reciprocal_ip becomes under Verilator,
// the reference is the C++ compiler.

#include <cstdlib>
#include <cstring>
#include <random>
#include <string>
#include <vector>

#include "Vfcore_reciprocal_ip_shim.h"
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

/// What the reciprocal does: 1 divided by the operand as a float, with a denormal result flushed to zero
class fcore_reciprocal_model {
public:
    uint32_t generate(std::mt19937_64 &rng) const {return fp32::generate(rng);}

    uint32_t reference(uint32_t operand) const {return fp32::flush_denormal(raw_reciprocal(operand));}

    /// Empty when the result is the expected one, otherwise what is wrong with it. The tag is the operand
    std::string compare(const sctb::axis_beat<> &expected, const sctb::axis_beat<> &actual, uint64_t tag) const {
        if(!fp32::matches(actual.data, expected.data)){
            return sctb::format("wrong result: 1 / %s, out = %s, expected = %s", sctb::hex(tag, 8).c_str(),
                                sctb::hex(actual.data, 8).c_str(), sctb::hex(expected.data, 8).c_str());
        }
        if(!actual.same_sideband(expected)){
            return sctb::format("sideband is not the one of the operand: 1 / %s, dest/user/tlast = %u/%u/%d, expected %u/%u/%d",
                                sctb::hex(tag, 8).c_str(), actual.dest, actual.user, actual.tlast,
                                expected.dest, expected.user, expected.tlast);
        }
        return {};
    }

    static std::vector<std::string> get_class_names() {return {"zero", "flushed denormal", "normal", "infinity", "nan"};}

    /// Which kind of result the operand gives
    size_t classify(uint32_t operand) const {
        const uint32_t raw = raw_reciprocal(operand);
        const uint32_t exponent = raw & fp32::exponent_mask;
        if(fp32::is_nan(raw)) return 4;
        if(exponent == fp32::exponent_mask) return 3;
        if(exponent == 0) return (raw & fp32::mantissa_mask) == 0 ? 0 : 1;
        return 2;
    }

private:
    // the reciprocal before a denormal is flushed
    static uint32_t raw_reciprocal(uint32_t operand) {return fp32::to_bits(1.0f / fp32::to_float(operand));}
};

/// Reset, a stream of random operations, wait for the pipeline to empty, then the checks of the totals.
/// Every operation is put on the input stream and the result it must give is said right after, the scoreboard compares
/// it with what comes out
class fcore_reciprocal_sequence {
public:
    fcore_reciprocal_sequence(const fcore_reciprocal_model &model, sctb::axis_source<> &operand_a, const sctb::clock &clk, sc_signal<bool> &reset,
                   sctb::scoreboard<sctb::axis_beat<>> &scoreboard, sctb::coverpoint &result_classes, sctb::covergroup &coverage, int64_t n_vectors) :
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
    // two conversions of two cycles and one cycle for the division
    static constexpr int latency = 5;
    static constexpr int reset_cycles = 4;
    static constexpr int drain_cycles = 16;
    static constexpr uint32_t user_offset = 5;

    const fcore_reciprocal_model &model;
    sctb::axis_master<> &a;
    const sctb::clock &clk;
    sc_signal<bool> &reset;
    sctb::scoreboard<sctb::axis_beat<>> &scoreboard;
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
    const fcore_reciprocal_model model;

    // the clock and the reset
    sctb::clock clk("clock");
    sc_signal<bool> reset("reset");

    // the device
    Vfcore_reciprocal_ip_shim dut("dut");
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
    sctb::scoreboard<sctb::axis_beat<>> scoreboard("fcore_reciprocal_ip", model, &fcore_reciprocal_model::compare, clk.get_period());
    sctb::coverpoint result_classes("result class", model.get_class_names());
    sctb::covergroup coverage;
    coverage.add(result_classes);

    result.add_listener(scoreboard, &sctb::scoreboard<sctb::axis_beat<>>::observe);

    fcore_reciprocal_sequence sequence(model, operand_a, clk, reset, scoreboard, result_classes, coverage, n_vectors);
    sctb::spawn("sequence", sequence, &fcore_reciprocal_sequence::run);

    const int result_code = sctb::run();
    dut.final();
    return result_code;
}
