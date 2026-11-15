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

#ifndef SCTB_SCOREBOARD_HPP
#define SCTB_SCOREBOARD_HPP

#include <systemc.h>

#include <cstdint>
#include <deque>
#include <functional>
#include <string>

#include "sctb/axis.hpp"

namespace sctb {

    /// Checks that what comes out of a device is what the reference model said would come out. The beats are
    /// matched in order. The latency is measured on the way, from the time a beat is expected (when its input
    /// went in) to the time it is observed (when it came out)
    /// It is the beat of the streams it watches, axis_beat<> for a bus, and a narrower one for a stream whose data
    /// is narrower, like axis_beat<uint32_t>
    template<typename beat_type = axis_beat<>>
    class scoreboard {
    public:
        /// Returns an empty string when the beats match, otherwise what differs. The third argument is the tag given
        /// to expect(), which the scoreboard carries through and never looks at
        using compare_function = std::function<std::string(const beat_type &expected, const beat_type &actual, uint64_t tag)>;

        /// The comparison of a test that has nothing to say about the input: it is not given the tag
        using compare_function_without_tag = std::function<std::string(const beat_type &expected, const beat_type &actual)>;

        scoreboard(const std::string &name, compare_function compare, sc_time clock_period);
        scoreboard(const std::string &name, compare_function_without_tag compare, sc_time clock_period);

        /// The comparison is a member function of an object
        template<typename T>
        scoreboard(const std::string &name, const T &object, std::string (T::*method)(const beat_type &, const beat_type &, uint64_t) const, sc_time clock_period) :
            scoreboard(name, [&object, method](const beat_type &expected, const beat_type &actual, uint64_t tag) {
                return (object.*method)(expected, actual, tag);
            }, clock_period) {}

        /// The comparison of a test that has nothing to say about the input
        template<typename T>
        scoreboard(const std::string &name, const T &object, std::string (T::*method)(const beat_type &, const beat_type &) const, sc_time clock_period) :
            scoreboard(name, [&object, method](const beat_type &expected, const beat_type &actual) {
                return (object.*method)(expected, actual);
            }, clock_period) {}

        /// The tag is opaque to the scoreboard: it stores it with the expected beat and gives it back to the
        /// comparison unchanged. It is whatever the test needs to report, for example the input that produced the beat
        void expect(const beat_type &beat, uint64_t tag = 0);
        void observe(const beat_type &beat);

        /// To be called when the test is over: what is still waiting never came out
        void finish();

        size_t get_pending() const {return waiting.size();}
        int64_t get_checked() const {return checked;}
        /// In clock cycles, only meaningful once something has been checked
        int64_t get_min_latency() const {return min_latency;}
        int64_t get_max_latency() const {return max_latency;}

    private:
        struct waiting_beat {
            beat_type beat;
            uint64_t tag;
            sc_time time;
        };

        std::string name;
        compare_function compare;
        sc_time clock_period;
        std::deque<waiting_beat> waiting;
        int64_t checked = 0;
        int64_t min_latency = INT64_MAX;
        int64_t max_latency = INT64_MIN;
    };

    // the beat of a bus, and the one of a stream whose data is a word: those are the ones the library is built for
    extern template class scoreboard<>;
    extern template class scoreboard<axis_beat<uint32_t, uint32_t, uint32_t>>;

}

#endif //SCTB_SCOREBOARD_HPP
