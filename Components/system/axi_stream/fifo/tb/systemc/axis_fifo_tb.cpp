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

// Self checking testbench for axis_fifo: every beat has to come out unchanged and in the order it went in,
// while the sink stalls the output at random

#include <algorithm>
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
#include "sctb/verilator.hpp"

class axis_fifo_model {
public:

    sctb::axis_beat<uint32_t, uint32_t, uint32_t> generate(std::mt19937_64 &rng) const {
        sctb::axis_beat<uint32_t, uint32_t, uint32_t> result;
        result.data = rng();
        result.dest = rng();
        result.user = rng();
        result.tlast = rng() & 1;
        return result;
    }

    /// Empty when the result is the expected one, otherwise what is wrong with it
    std::string compare(const sctb::axis_beat<uint32_t, uint32_t, uint32_t> &expected, const sctb::axis_beat<uint32_t, uint32_t, uint32_t> &actual, uint64_t input) const {
        // a FIFO carries every field through untouched
        if(actual.data != expected.data) return sctb::format("data is 0x%08x, expected 0x%08x", actual.data, expected.data);
        if(actual.dest != expected.dest) return sctb::format("dest is 0x%08x, expected 0x%08x", actual.dest, expected.dest);
        if(actual.user != expected.user) return sctb::format("user is 0x%08x, expected 0x%08x", actual.user, expected.user);
        if(actual.tlast != expected.tlast) return sctb::format("tlast is %d, expected %d", actual.tlast, expected.tlast);
        return {};
    }

private:

};


class axis_fifo_sequence {
public:
    axis_fifo_sequence(
        const axis_fifo_model &model, 
        sctb::axis_source<uint32_t, uint32_t, uint32_t> &input, 
        sctb::axis_sink<uint32_t, uint32_t, uint32_t> &output, 
        const sctb::clock &clk, 
        sc_signal<bool> &reset,
        sctb::scoreboard<sctb::axis_beat<uint32_t, uint32_t, uint32_t>> &scoreboard,
        int64_t n_vectors
    ) :
        model(model),
        master(input.get_master()),
        slave(output.get_slave()),
        clk(clk),
        reset(reset), 
        scoreboard(scoreboard), 
        n_vectors(n_vectors), 
        rng(1) {
        
    }

    void run() {
        sctb::reset_sequence(reset, clk, reset_cycles);
        clk.wait_cycles(10);
        sctb::progress progress(n_vectors);
        // the sink is ready 10% of the time for the first tenth of the vectors, 20% for the next one, up to always
        const int64_t phase_vectors = std::max<int64_t>(1, n_vectors / ready_phases);
        for(int64_t i = 0; i < n_vectors; i++){
            if(i % phase_vectors == 0 && i / phase_vectors < ready_phases) {
                slave.set_ready_probability(static_cast<double>(i / phase_vectors + 1) / ready_phases);
            }
            progress.update(i);
            auto in = model.generate(rng);
            master.write(in);
            scoreboard.expect(in, in.data);
        }
        progress.finish();

        master.idle();
        sctb::drain(scoreboard, clk, drain_cycles);
        scoreboard.finish();
        sctb::reporter::instance().info(sctb::format("%lld vectors checked", static_cast<long long>(scoreboard.get_checked())));
        sctb::finish();
    }

private:
    static constexpr int reset_cycles = 4;
    static constexpr int ready_phases = 10;
    // the most the sink needs to empty a full FIFO, with room to spare. The drain stops as soon as nothing is pending
    static constexpr int drain_cycles = 200;

    const axis_fifo_model &model;
    sctb::axis_master<uint32_t, uint32_t, uint32_t> &master;
    sctb::axis_slave<uint32_t, uint32_t, uint32_t> &slave;
    const sctb::clock &clk;
    sc_signal<bool> &reset;
    sctb::scoreboard<sctb::axis_beat<uint32_t, uint32_t, uint32_t>> &scoreboard;
    int64_t n_vectors;
    std::mt19937_64 rng;
};

int sc_main(int argc, char *argv[]) {
    Verilated::commandArgs(argc, argv);
    sctb::init();

    constexpr int64_t default_vectors = 100000;
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
    sctb::axis_sink<uint32_t, uint32_t, uint32_t> output("out", clk, 32, 0.5);
    input.connect(dut);
    output.connect(dut);
    
    // the waveform, written when the command line has --trace=<file>
    sctb::trace trace(options, clk);
    trace.add("reset", reset);
    trace.add(input);
    trace.add(output);
    trace.add_dut(dut);

    // the checking: the sequence says what each input must give, the sink hands what comes out to the scoreboard
    sctb::scoreboard<sctb::axis_beat<uint32_t, uint32_t, uint32_t>> scoreboard("axis_fifo", model, &axis_fifo_model::compare, clk.get_period());

    output.add_listener(scoreboard, &sctb::scoreboard<sctb::axis_beat<uint32_t, uint32_t, uint32_t>>::observe);

    axis_fifo_sequence sequence(model, input, output, clk, reset, scoreboard, n_vectors);
    sctb::spawn("sequence", sequence, &axis_fifo_sequence::run);

    const int result = sctb::run();
    dut.final();
    return result;
}
