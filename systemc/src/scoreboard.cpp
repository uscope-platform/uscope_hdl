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

#include "sctb/scoreboard.hpp"

#include <algorithm>
#include <cmath>

#include "sctb/report.hpp"

namespace sctb {

    scoreboard::scoreboard(const std::string &board_name, compare_function compare_beats, sc_time period) :
        name(board_name), compare(compare_beats), clock_period(period) {}

    void scoreboard::expect(const axis_beat &beat, uint64_t tag) {
        waiting.push_back({beat, tag, sc_time_stamp()});
    }

    void scoreboard::observe(const axis_beat &beat) {
        auto &report = reporter::instance();
        if(waiting.empty()) {
            report.error(format("[%s] a result came out while none was expected", name.c_str()));
            return;
        }
        const waiting_beat expected = waiting.front();
        waiting.pop_front();
        checked++;

        const std::string mismatch = compare(expected.beat, beat, expected.tag);
        if(!mismatch.empty()) report.error(format("[%s] %s", name.c_str(), mismatch.c_str()));

        const int64_t latency = std::llround((sc_time_stamp() - expected.time) / clock_period);
        min_latency = std::min(min_latency, latency);
        max_latency = std::max(max_latency, latency);
    }

    void scoreboard::finish() {
        if(waiting.empty()) return;
        reporter::instance().error(format("[%s] %zu expected results never came out", name.c_str(), waiting.size()));
    }

}
