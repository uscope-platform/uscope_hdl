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

#ifndef SCTB_RUN_HPP
#define SCTB_RUN_HPP

#include <systemc.h>

#include <functional>
#include <string>

#include "sctb/clocking.hpp"

namespace sctb {

    /// Has to be the first thing in sc_main. The resolution has to match the timeprecision of the RTL
    void init(double resolution = 1, sc_time_unit unit = SC_NS);

    /// Starts a thread when the simulation starts, like an initial block. This is where the test sequence goes,
    /// as it is the only kind of process that can wait
    void spawn(const std::string &name, std::function<void()> body);
    template<typename T>
    void spawn(const std::string &name, T &object, void (T::*method)()) {spawn(name, std::function<void()>(std::bind(method, &object)));}

    /// Runs a function on every rising edge of the clock. It runs a function that returns, which is much cheaper than a thread
    void spawn_every_cycle(const std::string &name, const clock &clk, std::function<void()> body);
    template<typename T>
    void spawn_every_cycle(const std::string &name, const clock &clk, T &object, void (T::*method)()) {
        spawn_every_cycle(name, clk, std::function<void()>(std::bind(method, &object)));
    }

    /// Runs a function every time an event happens, for example the change of a signal. Like spawn_every_cycle it runs a function that returns
    void spawn_on_event(const std::string &name, const sc_event &event, std::function<void()> body);
    template<typename T>
    void spawn_on_event(const std::string &name, const sc_event &event, T &object, void (T::*method)()) {
        spawn_on_event(name, event, std::function<void()>(std::bind(method, &object)));
    }

    /// Ends the simulation
    void finish();

    /// Runs until finish() is called, or until the timeout if there is one. Returns the exit code of the test
    int run(sc_time timeout = SC_ZERO_TIME);

}

#endif //SCTB_RUN_HPP
