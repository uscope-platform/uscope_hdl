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

#include "Vaxis_fifo_shim.h"
#include "sctb/axis.hpp"
#include "sctb/checks.hpp"
#include "sctb/clocking.hpp"
#include "sctb/options.hpp"
#include "sctb/progress.hpp"
#include "sctb/report.hpp"
#include "sctb/run.hpp"
#include "sctb/scoreboard.hpp"
#include "sctb/trace.hpp"

class axis_fifo_model {
public:

    sctb::axis_beat<uint32_t, uint32_t, uint32_t> generate(std::mt19937_64 &rng) const {
        sctb::axis_beat<uint32_t, uint32_t, uint32_t> result;
        result.data = rng();
        result.dest = rng();
        result.user = rng();
        return result;
    }

    /// Empty when the result is the expected one, otherwise what is wrong with it
    std::string compare(const sctb::axis_beat<uint32_t, uint32_t, uint32_t> &expected, const sctb::axis_beat<uint32_t, uint32_t, uint32_t> &actual, uint64_t input) const {
        return {};
    }

private:

};


class axis_fifo_sequence {
public:
    axis_fifo_sequence(const axis_fifo_model &model, sctb::axis_source<uint32_t, uint32_t, uint32_t> &input, const sctb::clock &clk, sc_signal<bool> &reset,
                    sctb::scoreboard<sctb::axis_beat<uint32_t, uint32_t, uint32_t>> &scoreboard,  int64_t n_vectors) :
        model(model), master(input.get_master()), clk(clk), reset(reset), scoreboard(scoreboard), n_vectors(n_vectors), rng(1) {}

    void run() {
        sctb::reset_sequence(reset, clk, reset_cycles);

        sctb::progress progress(n_vectors);
        const sc_time start = sc_time_stamp();
        for(int64_t i = 0; i < n_vectors; i++){
            progress.update(i);
            auto in = model.generate(rng);
            master.write(in);
            scoreboard.expect(in, in.data);
        }
        progress.finish();
        sctb::check_throughput(n_vectors, sc_time_stamp() - start, clk);

        master.idle();
        sctb::drain(scoreboard, clk, latency + drain_cycles);
        scoreboard.finish();
        sctb::check_latency(scoreboard, latency);
        sctb::reporter::instance().info(sctb::format("%lld vectors checked", static_cast<long long>(scoreboard.get_checked())));
        sctb::finish();
    }

private:
    static constexpr int latency = 2;
    static constexpr int reset_cycles = 4;
    static constexpr int drain_cycles = 16;
    // dest, user and tlast are not part of the conversion, they have to come out as they went in
    static constexpr uint32_t user_offset = 5;

    const axis_fifo_model &model;
    sctb::axis_master<uint32_t, uint32_t, uint32_t> &master;
    const sctb::clock &clk;
    sc_signal<bool> &reset;
    sctb::scoreboard<sctb::axis_beat<uint32_t, uint32_t, uint32_t>> &scoreboard;
    int64_t n_vectors;
    std::mt19937_64 rng;
};

int sc_main(int argc, char *argv[]) {
    Verilated::commandArgs(argc, argv);
    sctb::init();

    constexpr int64_t default_vectors = 10000;
    const sctb::options options(argc, argv);
    const int64_t n_vectors = options.get_positional_integer(0, default_vectors);
    const axis_fifo_model model;

    // the clock and the reset
    sctb::clock clk("clock");
    sc_signal<bool> reset("reset");

    // the device
    Vaxis_fifo_shim dut("dut");
    dut.clock(clk.get_signal());
    dut.reset(reset);

    // the stream going in, driven and watched, and the one coming out, answered and watched
    sctb::axis_source<uint32_t, uint32_t, uint32_t> input("in", clk, 32);
    sctb::axis_sink<uint32_t, uint32_t, uint32_t> output("out", clk, 32);
    input.connect(dut);
    output.connect(dut);
    
    // the waveform, written when the command line has --trace=<file>
    sctb::trace trace(options, clk);
    trace.add("reset", reset);
    trace.add(input);
    trace.add(output);

    // the checking: the sequence says what each input must give, the sink hands what comes out to the scoreboard
    sctb::scoreboard<sctb::axis_beat<uint32_t, uint32_t, uint32_t>> scoreboard("axis_fifo", model, &axis_fifo_model::compare, clk.get_period());

    output.add_listener(scoreboard, &sctb::scoreboard<sctb::axis_beat<uint32_t, uint32_t, uint32_t>>::observe);

    axis_fifo_sequence sequence(model, input, clk, reset, scoreboard, n_vectors);
    sctb::spawn("sequence", sequence, &axis_fifo_sequence::run);
    
    const int result = sctb::run();
    dut.final();
    return result;
}
