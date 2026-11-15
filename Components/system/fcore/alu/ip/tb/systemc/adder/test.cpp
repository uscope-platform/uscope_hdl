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

// Self checking testbench for the model of the floating point adder IP that fcore_adder_ip becomes under Verilator,
// the reference is the float addition of the C++ compiler. The three input streams are driven in the same cycle.

#include <cstdlib>
#include <cstring>
#include <random>
#include <string>
#include <vector>

#include "Vfcore_adder_ip_shim.h"
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

/// What the adder does: the float sum of the two operands, with a denormal result flushed to zero. A subtraction is
/// the addition of the second operand with its sign flipped, so the model only has additions: "added" is the second
/// operand as it is added
class fcore_adder_model {
public:
    void generate(std::mt19937_64 &rng, uint32_t &a, uint32_t &b) const {
        a = fp32::generate(rng);
        if(rng() % 4 == 0){
            // close to the opposite of a, which cancels most of the bits or all of them
            b = (a ^ fp32::sign_mask) ^ (static_cast<uint32_t>(rng()) & (0xFFFFFFFFu >> (rng() % 32)));
        } else {
            b = fp32::generate(rng);
        }
    }

    uint32_t reference(uint32_t a, uint32_t added) const {return fp32::flush_denormal(raw_sum(a, added));}

    /// Empty when the result is the expected one, otherwise what is wrong with it. The tag is the operands
    std::string compare(const sctb::axis_beat<> &expected, const sctb::axis_beat<> &actual, uint64_t tag) const {
        const std::string operands = sctb::hex(tag & 0xFFFFFFFF, 8) + " + " + sctb::hex(tag >> 32, 8);
        if(!fp32::matches(actual.data, expected.data)){
            return sctb::format("wrong result: %s, out = %s, expected = %s", operands.c_str(),
                                sctb::hex(actual.data, 8).c_str(), sctb::hex(expected.data, 8).c_str());
        }
        if(!actual.same_sideband(expected)){
            return sctb::format("sideband is not the one of operand a: %s, dest/user/tlast = %u/%u/%d, expected %u/%u/%d",
                                operands.c_str(), actual.dest, actual.user, actual.tlast,
                                expected.dest, expected.user, expected.tlast);
        }
        return {};
    }

    static uint64_t get_tag(uint32_t a, uint32_t added) {return a | (static_cast<uint64_t>(added) << 32);}

    /// Which kind of result the operands give
    size_t classify(uint32_t a, uint32_t added) const {return fp32::binary_class(raw_sum(a, added), a, added);}

    static std::vector<std::string> get_operation_names() {return {"add", "subtract"};}

private:
    // the sum before a denormal is flushed
    static uint32_t raw_sum(uint32_t a, uint32_t added) {return fp32::to_bits(fp32::to_float(a) + fp32::to_float(added));}
};

/// Reset, a stream of random operations, wait for the pipeline to empty, then the checks of the totals.
/// Every operation is put on the three input streams in the same cycle and the result it must give is said right
/// after, the scoreboard compares it with what comes out
class fcore_adder_sequence {
public:
    fcore_adder_sequence(const fcore_adder_model &model, sctb::axis_source<> &operand_a, sctb::axis_source<> &operand_b,
                         sctb::axis_source<> &operation, const sctb::clock &clk, sc_signal<bool> &reset, sctb::scoreboard<> &scoreboard,
                         sctb::coverpoint &result_classes, sctb::coverpoint &operations, sctb::covergroup &coverage, int64_t n_vectors) :
        model(model), a(operand_a.get_master()), b(operand_b.get_master()), op(operation.get_master()), clk(clk), reset(reset),
        scoreboard(scoreboard), result_classes(result_classes), operations(operations), coverage(coverage), n_vectors(n_vectors), rng(1) {}

    void run() {
        sctb::reset_sequence(reset, clk, reset_cycles);

        sctb::progress progress(n_vectors);
        const sc_time start = sc_time_stamp();
        for(int64_t i = 0; i < n_vectors; i++){
            progress.update(i);
            const auto n = static_cast<uint32_t>(i);
            uint32_t operand_a;
            uint32_t operand_b;
            model.generate(rng, operand_a, operand_b);
            const bool subtract = (rng() & 1) != 0;
            const uint32_t added = subtract ? operand_b ^ fp32::sign_mask : operand_b;

            // the sideband of the result is the one of operand a, the IP has no dest and no tlast
            a.put(operand_a, n, n + user_offset, (n & 1) != 0);
            b.put(operand_b);
            op.put(subtract ? 1 : 0);
            clk.wait_cycles(1);

            operations.hit(subtract ? 1 : 0);
            result_classes.hit(model.classify(operand_a, added));
            scoreboard.expect({model.reference(operand_a, added), 0, n + user_offset, false}, fcore_adder_model::get_tag(operand_a, added));
        }
        progress.finish();
        sctb::check_throughput(n_vectors, sc_time_stamp() - start, clk);

        a.idle();
        b.idle();
        op.idle();
        sctb::drain(scoreboard, clk, latency + drain_cycles);
        scoreboard.finish();
        sctb::check_latency(scoreboard, latency);
        coverage.report();
        sctb::reporter::instance().info(sctb::format("%lld vectors checked", static_cast<long long>(scoreboard.get_checked())));
        sctb::finish();
    }

private:
    // two conversions of two cycles and one cycle for the sum
    static constexpr int latency = 5;
    static constexpr int reset_cycles = 4;
    static constexpr int drain_cycles = 16;
    static constexpr uint32_t user_offset = 5;

    const fcore_adder_model &model;
    sctb::axis_master<> &a;
    sctb::axis_master<> &b;
    sctb::axis_master<> &op;
    const sctb::clock &clk;
    sc_signal<bool> &reset;
    sctb::scoreboard<> &scoreboard;
    sctb::coverpoint &result_classes;
    sctb::coverpoint &operations;
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
    const fcore_adder_model model;

    // the clock and the reset
    sctb::clock clk("clock");
    sc_signal<bool> reset("reset");

    // the device
    Vfcore_adder_ip_shim dut("dut");
    dut.clock(clk.get_signal());
    dut.reset(reset);

    // the three streams going in, driven, and the one coming out, answered and watched
    sctb::axis_source<> operand_a("a", clk, 32);
    sctb::axis_source<> operand_b("b", clk, 32);
    sctb::axis_source<> operation("op", clk, 32);
    sctb::axis_sink<> result("result", clk, 32);
    operand_a.connect(dut);
    operand_b.connect(dut);
    operation.connect(dut);
    result.connect(dut);

    // the waveform, written when the command line has --trace=<file>
    sctb::trace trace(options, clk);
    trace.add("reset", reset);
    trace.add(operand_a);
    trace.add(operand_b);
    trace.add(operation);
    trace.add(result);

    // the checking: the sequence says what each operation must give, the sink hands what comes out to the scoreboard
    sctb::scoreboard<> scoreboard("fcore_adder_ip", model, &fcore_adder_model::compare, clk.get_period());
    sctb::coverpoint result_classes("result class", fp32::binary_class_names());
    sctb::coverpoint operations("operation", model.get_operation_names());
    sctb::covergroup coverage;
    coverage.add(result_classes);
    coverage.add(operations);

    result.add_listener(scoreboard, &sctb::scoreboard<>::observe);

    fcore_adder_sequence sequence(model, operand_a, operand_b, operation, clk, reset, scoreboard, result_classes, operations, coverage, n_vectors);
    sctb::spawn("sequence", sequence, &fcore_adder_sequence::run);

    const int result_code = sctb::run();
    dut.final();
    return result_code;
}
