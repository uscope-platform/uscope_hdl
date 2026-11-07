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

#ifndef SCTB_AXIS_SLAVE_HPP
#define SCTB_AXIS_SLAVE_HPP

#include <systemc.h>

#include <cstdint>
#include <functional>
#include <random>
#include <string>

#include "sctb/axis/bus.hpp"
#include "sctb/axis/monitor.hpp"
#include "sctb/clocking.hpp"

namespace sctb {

    /// Answers a bus with ready and tells the listeners what it received
    class axis_slave {
    public:
        /// ready_probability is the chance that ready is high in a cycle, with 1 it is always high
        axis_slave(const std::string &name, axis_bus &bus, const clock &clk, double ready_probability = 1.0, uint64_t seed = 1);

        void add_listener(std::function<void(const axis_beat &)> listener) {monitor.add_listener(listener);}
        template<typename T>
        void add_listener(T &object, void (T::*method)(const axis_beat &)) {monitor.add_listener(object, method);}

    private:
        void drive_ready();

        axis_monitor monitor;
        axis_bus &bus;
        double probability;
        std::mt19937_64 rng;
        std::uniform_real_distribution<double> chance;
    };

}

#endif //SCTB_AXIS_SLAVE_HPP
