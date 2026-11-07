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

#ifndef SCTB_AXIS_MONITOR_HPP
#define SCTB_AXIS_MONITOR_HPP

#include <systemc.h>

#include <functional>
#include <string>
#include <vector>

#include "sctb/axis/bus.hpp"
#include "sctb/clocking.hpp"

namespace sctb {

    /// Only watches a bus, and tells the listeners about every transfer in the cycle it happens
    class axis_monitor {
    public:
        axis_monitor(const std::string &name, axis_bus &bus, const clock &clk);

        void add_listener(std::function<void(const axis_beat &)> listener) {listeners.push_back(listener);}
        /// The listener is a member function of an object
        template<typename T>
        void add_listener(T &object, void (T::*method)(const axis_beat &)) {add_listener(std::bind(method, &object, std::placeholders::_1));}

    private:
        void sample();

        axis_bus &bus;
        std::vector<std::function<void(const axis_beat &)>> listeners;
    };

}

#endif //SCTB_AXIS_MONITOR_HPP
