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

#ifndef SCTB_CHECKS_HPP
#define SCTB_CHECKS_HPP

#include <systemc.h>

#include <cstdint>

#include "sctb/clocking.hpp"
#include "sctb/report.hpp"
#include "sctb/scoreboard.hpp"

namespace sctb {

    /// The end of test checks of a pipeline, each one reports to the reporter. They can be used on their own,
    /// a test picks the ones that make sense for the device

    /// Waits for what is still in the device to come out, up to a number of cycles. Call it from a thread
    template<typename beat_type>
    void drain(const scoreboard<beat_type> &board, const clock &clk, int64_t max_cycles) {
        for(int64_t cycle = 0; cycle < max_cycles && board.get_pending() != 0; cycle++){
            clk.wait_cycles(1);
        }
    }

    /// Every result has to take the same number of cycles, and it has to be the one of the device
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

    /// A device that takes a beat every cycle takes n cycles for n beats, give or take the cycle the sequence starts in
    void check_throughput(int64_t beats, sc_time elapsed, const clock &clk);

}

#endif //SCTB_CHECKS_HPP
