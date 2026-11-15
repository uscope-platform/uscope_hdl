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

#include "sctb/checks.hpp"

#include <cmath>

#include "sctb/report.hpp"

namespace sctb {

    template<typename beat_type>
    void drain(const scoreboard<beat_type> &board, const clock &clk, int64_t max_cycles) {
        for(int64_t cycle = 0; cycle < max_cycles && board.get_pending() != 0; cycle++){
            clk.wait_cycles(1);
        }
    }

    template<typename beat_type>
    void check_latency(const scoreboard<beat_type> &board, int64_t cycles) {
        auto &report = reporter::instance();
        if(board.get_checked() == 0) {
            report.error("no result came out");
        } else if(board.get_min_latency() != cycles || board.get_max_latency() != cycles) {
            report.error(format("latency is %lld to %lld cycles, expected %lld", static_cast<long long>(board.get_min_latency()),
                                static_cast<long long>(board.get_max_latency()), static_cast<long long>(cycles)));
        }
    }

    // the beat of a bus, and the one of a stream whose data is a word
    template void drain<>(const scoreboard<> &board, const clock &clk, int64_t max_cycles);
    template void drain<>(const scoreboard<axis_beat<uint32_t, uint32_t, uint32_t>> &board, const clock &clk, int64_t max_cycles);
    template void check_latency<>(const scoreboard<> &board, int64_t cycles);
    template void check_latency<>(const scoreboard<axis_beat<uint32_t, uint32_t, uint32_t>> &board, int64_t cycles);

    void check_throughput(int64_t beats, sc_time elapsed, const clock &clk) {
        const int64_t cycles = std::llround(elapsed / clk.get_period());
        if(cycles <= beats + 2) return;
        reporter::instance().error(format("%lld beats took %lld cycles, the input stalled",
                                          static_cast<long long>(beats), static_cast<long long>(cycles)));
    }

}
