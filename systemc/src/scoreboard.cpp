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

    template<typename beat_type>
    scoreboard<beat_type>::scoreboard(const std::string &board_name, compare_function compare_beats, sc_time period) :
        name(board_name), compare(compare_beats), clock_period(period) {}

    template<typename beat_type>
    scoreboard<beat_type>::scoreboard(const std::string &board_name, compare_function_without_tag compare_beats, sc_time period) :
        scoreboard(board_name, [compare_beats](const beat_type &expected, const beat_type &actual, uint64_t) {
            return compare_beats(expected, actual);
        }, period) {}

    template<typename beat_type>
    void scoreboard<beat_type>::expect(const beat_type &beat, uint64_t tag) {
        waiting.push_back({beat, tag, sc_time_stamp()});
    }

    template<typename beat_type>
    void scoreboard<beat_type>::observe(const beat_type &beat) {
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

    template<typename beat_type>
    void scoreboard<beat_type>::finish() {
        if(waiting.empty()) return;
        reporter::instance().error(format("[%s] %zu expected results never came out", name.c_str(), waiting.size()));
    }

    // the beat of a bus, and the one of a stream whose data is a word
    template class scoreboard<>;
    template class scoreboard<axis_beat<uint32_t, uint32_t, uint32_t>>;

}
