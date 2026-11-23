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


// Self checking testbench for axi_watchdog. The device sits between a master and a slave and has to let the traffic
// through, and when the slave stops answering it has to answer the master in its place after the timeout, so that the
// master is not stuck for good. The slave is played by sctb::axi_slave, which can be told to go silent.
//
// What the watchdog has to do is written down here, as the RTL does not say it:
//   * a transaction is passed through unchanged, with the response and the data of the slave. A monitor on the interface
//     of the slave hands what it saw to two scoreboards, one of writes and one of reads
//   * when the slave does not answer within the timeout the master gets an answer with an error response (SLVERR), a
//     read gets its beat with rlast, and the bus is free for the next transaction
//   * a slave that answers slowly, but within the timeout, is not mistaken for a hung one

#include <cstdlib>
#include <random>
#include <vector>

#include "Vaxi_watchdog_shim.h"
#include "sctb/axi.hpp"
#include "sctb/clocking.hpp"
#include "sctb/options.hpp"
#include "sctb/progress.hpp"
#include "sctb/report.hpp"
#include "sctb/checks.hpp"
#include "sctb/run.hpp"
#include "sctb/scoreboard.hpp"
#include "sctb/trace.hpp"
#include "sctb/verilator.hpp"

/// What the watchdog has to do to a transaction: nothing. The slave has to see it as the master sent it, which is
/// what the scoreboards compare it to
class axi_watchdog_model {
public:
    /// A write of the master as the slave has to see it: the same address and data, every byte written, and okay
    sctb::axi_write expected_write(uint64_t address, const std::vector<uint64_t> &data) const {
        sctb::axi_write result;
        result.address = address;
        result.data = data;
        result.strobe.assign(data.size(), 0xf);
        return result;
    }

    sctb::axi_read expected_read(uint64_t address, uint32_t beats, const std::vector<uint64_t> &memory_has) const {
        sctb::axi_read result;
        result.address = address;
        result.beats = beats;
        result.data = memory_has;
        return result;
    }

    /// Empty when the transaction is the expected one, otherwise what is wrong with it
    std::string compare(const sctb::axi_write &expected, const sctb::axi_write &actual) const {return sctb::compare(expected, actual);}
    std::string compare_read(const sctb::axi_read &expected, const sctb::axi_read &actual) const {return sctb::compare(expected, actual);}
};

class axi_watchdog_sequence {
public:
    axi_watchdog_sequence(
        const axi_watchdog_model &model,
        sctb::axi_master &master,
        sctb::axi_slave &slave,
        const sctb::clock &clk,
        sc_signal<bool> &reset,
        sctb::scoreboard<sctb::axi_write> &write_board,
        sctb::scoreboard<sctb::axi_read> &read_board,
        sctb::trace &trace,
        int64_t n_vectors
    ) :
        model(model), master(master), slave(slave), clk(clk), reset(reset), write_board(write_board), read_board(read_board), trace(trace),
        n_vectors(n_vectors), rng(1) {}

    /// Whether the transactions that reach the slave are the ones the scoreboards expect. It is off while the test makes
    /// the watchdog time out: what a timeout leaves on its way to the slave is not something to expect
    bool is_checking() const {return checking;}

    /// The stages of the test, in the order they happen, as the waveform shows them
    static std::vector<std::string> stage_names() {
        return {"reset", "pass_through", "slow_slave", "hung_write", "hung_read", "recovery", "pass_through_again"};
    }

    void run() {
        trace.stage("reset");
        sctb::reset_sequence(reset, clk, reset_cycles);
        clk.wait_cycles(10);

        trace.stage("pass_through");
        pass_through();
        trace.stage("slow_slave");
        slow_slave();
        // the transactions of the timeouts are not expected on the slave, they may or may not reach it
        stop_checking();
        trace.stage("hung_write");
        hung_write();
        trace.stage("hung_read");
        hung_read();
        trace.stage("recovery");
        start_checking();
        // whatever the timeouts left behind, the traffic has to go through again
        trace.stage("pass_through_again");
        pass_through();

        finish_boards();
        master.idle(10);
        sctb::finish();
    }

private:
    static constexpr int reset_cycles = 4;
    // the timeout of the shim, in cycles
    static constexpr int timeout = 64;
    // what the watchdog needs on top of the timeout to notice and answer
    static constexpr int margin = 16;
    static constexpr uint32_t memory_words = 256;
    static constexpr int drain_cycles = 4 * timeout;

    void error(const std::string &message) {sctb::reporter::instance().error(message);}

    int64_t cycles_since(sc_time start) const {return static_cast<int64_t>((sc_time_stamp() - start) / clk.get_period());}

    // sends a write, and says to the scoreboard what the slave has to see of it
    sctb::axi_response write(uint64_t address, const std::vector<uint64_t> &data) {
        write_board.expect(model.expected_write(address, data));
        return master.write_burst(address, data);
    }

    sctb::axi_response read(uint64_t address, uint32_t beats, std::vector<uint64_t> &data, const std::vector<uint64_t> &memory_has) {
        read_board.expect(model.expected_read(address, beats, memory_has));
        return master.read_burst(address, beats, data);
    }

    void settle() {
        sctb::drain(write_board, clk, drain_cycles);
        sctb::drain(read_board, clk, drain_cycles);
    }
    void stop_checking() {
        settle();
        checking = false;
    }
    void start_checking() {
        // what a timeout left on its way to the slave has arrived by now
        master.idle(2 * timeout);
        checking = true;
    }
    void finish_boards() {
        settle();
        write_board.finish();
        read_board.finish();
    }

    void pass_through() {
        sctb::progress progress(n_vectors);
        for(int64_t i = 0; i < n_vectors; i++){
            progress.update(i);
            const uint32_t beats = 1 + rng() % 16;
            const uint32_t first = rng() % (memory_words - beats);
            const uint64_t address = uint64_t(first) * 4;

            std::vector<uint64_t> data(beats);
            for(auto &beat : data) beat = static_cast<uint32_t>(rng());
            const sctb::axi_response written = write(address, data);
            if(written != sctb::axi_response::okay) error(sctb::format("write at 0x%llx answered %s", static_cast<unsigned long long>(address), sctb::to_string(written)));

            std::vector<uint64_t> actual;
            const sctb::axi_response response = read(address, beats, actual, data);
            if(response != sctb::axi_response::okay) error(sctb::format("read at 0x%llx answered %s", static_cast<unsigned long long>(address), sctb::to_string(response)));
            if(actual != data) error(sctb::format("the read of %u beats at 0x%llx did not give back what was written", beats, static_cast<unsigned long long>(address)));
        }
        progress.finish();
    }

    // an answer that takes half of the timeout is slow, not hung
    void slow_slave() {
        slave.set_latency(timeout / 2);
        for(int i = 0; i < 8; i++){
            const uint64_t address = uint64_t(rng() % memory_words) * 4;
            const std::vector<uint64_t> data = {uint64_t(0x1234 + i)};
            if(write(address, data) != sctb::axi_response::okay) error("a slow write was answered with an error, it is not hung");
            std::vector<uint64_t> actual;
            if(read(address, 1, actual, data) != sctb::axi_response::okay) error("a slow read was answered with an error, it is not hung");
            if(actual != data) error("a slow read gave the wrong data");
        }
        slave.set_latency(1);
    }

    void hung_write() {
        slave.set_hung(true);
        const sc_time start = sc_time_stamp();
        const sctb::axi_response response = master.write(0x40, 0xdeadbeef);
        const int64_t took = cycles_since(start);
        if(response != sctb::axi_response::slverr) error(sctb::format("a write to a hung slave was answered with %s, not SLVERR", sctb::to_string(response)));
        if(took < timeout) error(sctb::format("a write to a hung slave was given up after %lld cycles, before the timeout of %d", static_cast<long long>(took), timeout));
        if(took > timeout + margin) error(sctb::format("a write to a hung slave took %lld cycles to be given up, the timeout is %d", static_cast<long long>(took), timeout));
        slave.set_hung(false);
        master.idle(timeout);
        // the bus is free again
        if(master.write(0x44, 0x1) != sctb::axi_response::okay) error("a write after a timeout was not answered with okay");
        master.idle(timeout);
    }

    void hung_read() {
        slave.set_hung(true);
        const sc_time start = sc_time_stamp();
        uint64_t data = 0;
        const sctb::axi_response response = master.read(0x40, data);
        const int64_t took = cycles_since(start);
        if(response != sctb::axi_response::slverr) error(sctb::format("a read from a hung slave was answered with %s, not SLVERR", sctb::to_string(response)));
        if(took < timeout) error(sctb::format("a read from a hung slave was given up after %lld cycles, before the timeout of %d", static_cast<long long>(took), timeout));
        if(took > timeout + margin) error(sctb::format("a read from a hung slave took %lld cycles to be given up, the timeout is %d", static_cast<long long>(took), timeout));
        slave.set_hung(false);
        master.idle(timeout);
        if(master.read(0x44, data) != sctb::axi_response::okay) error("a read after a timeout was not answered with okay");
    }

    const axi_watchdog_model &model;
    sctb::axi_master &master;
    sctb::axi_slave &slave;
    const sctb::clock &clk;
    sc_signal<bool> &reset;
    sctb::scoreboard<sctb::axi_write> &write_board;
    sctb::scoreboard<sctb::axi_read> &read_board;
    sctb::trace &trace;
    int64_t n_vectors;
    std::mt19937_64 rng;
    bool checking = true;
};

int sc_main(int argc, char *argv[]) {
    Verilated::commandArgs(argc, argv);
    sctb::init();

    constexpr int64_t default_vectors = 2000;
    const sctb::options options(argc, argv);
    const int64_t n_vectors = options.get_positional_integer(0, default_vectors);

    // the clock and the reset
    sctb::clock clk("clock");
    sc_signal<bool> reset("reset");

    // the device
    Vaxi_watchdog_shim dut("dut");
    dut.clock(clk.get_signal());
    dut.reset(reset);

    // the interface the device is a slave of, driven, and the one it drives, answered
    sctb::axi_driver upstream("axi_in", clk);
    sctb::axi_responder downstream("axi_out", clk);
    upstream.connect(dut);
    downstream.connect(dut);

    // the waveform, written when the command line has --trace=<file>
    sctb::trace trace(options, clk);
    trace.add("reset", reset);
    trace.add(upstream);
    trace.add(downstream);
    trace.add_dut(dut);
    trace.define_stages(axi_watchdog_sequence::stage_names());

    // the checking: the sequence says what the slave has to see of each transaction it sends, and the monitor of the
    // interface of the slave hands what it saw to the scoreboards
    const axi_watchdog_model model;
    sctb::scoreboard<sctb::axi_write> write_board("downstream_writes", model, &axi_watchdog_model::compare, clk.get_period());
    sctb::scoreboard<sctb::axi_read> read_board("downstream_reads", model, &axi_watchdog_model::compare_read, clk.get_period());

    axi_watchdog_sequence sequence(model, upstream.get_master(), downstream.get_slave(), clk, reset, write_board, read_board, trace, n_vectors);

    sctb::axi_monitor monitor("downstream_monitor", downstream.get_bus(), clk);
    monitor.add_write_listener([&](const sctb::axi_write &write) {if(sequence.is_checking()) write_board.observe(write);});
    monitor.add_read_listener([&](const sctb::axi_read &read) {if(sequence.is_checking()) read_board.observe(read);});

    sctb::spawn("sequence", sequence, &axi_watchdog_sequence::run);

    // a watchdog that does not answer leaves the master waiting for ever, which is what the timeout is for
    const int result = sctb::run(sc_time(20, SC_MS));
    dut.final();
    return result;
}
