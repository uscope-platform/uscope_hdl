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

#ifndef SCTB_AXIS_ENDPOINTS_HPP
#define SCTB_AXIS_ENDPOINTS_HPP

#include <systemc.h>

#include <cstdint>
#include <functional>
#include <string>

#include "sctb/axis/bus.hpp"
#include "sctb/axis/connect.hpp"
#include "sctb/axis/master.hpp"
#include "sctb/axis/slave.hpp"
#include "sctb/clocking.hpp"

namespace sctb {

    /// The sending end of a stream of the device: the bus and a master that drives it. It is all the plumbing a
    /// stream going into a device needs

    template <typename data_type = uint64_t, typename dest_type = uint32_t, typename user_type = uint32_t>
    class axis_source {
    public:
        axis_source(const std::string &name, const clock &clk, uint32_t data_bits = 64, uint32_t dest_bits = 32, uint32_t user_bits = 32);

        /// Connects the ports of the model called <name>_valid and so on to the bus
        void connect(const sc_module &model) {connect_stream(bus, model, name);}

        const axis_bus &get_bus() const {return bus;}
        axis_master<data_type, dest_type, user_type> &get_master() {return master;}

    private:
        std::string name;
        axis_bus bus;
        axis_master<data_type, dest_type, user_type> master;
    };

    template <typename data_type = uint64_t, typename dest_type = uint32_t, typename user_type = uint32_t>
    class axis_sink {
    public:
        axis_sink(const std::string &name, const clock &clk, uint32_t data_bits = 64, double ready_probability = 1.0, uint64_t seed = 1,
                  uint32_t dest_bits = 32, uint32_t user_bits = 32);

        /// Connects the ports of the model called <name>_valid and so on to the bus
        void connect(const sc_module &model) {connect_stream(bus, model, name);}

        const axis_bus &get_bus() const {return bus;}
        axis_slave<data_type, dest_type, user_type> &get_slave() {return slave;}

        void add_listener(std::function<void(const axis_beat<data_type, dest_type, user_type> &)> listener) {slave.add_listener(listener);}
        template<typename T>
        void add_listener(T &object, void (T::*method)(const axis_beat<data_type, dest_type, user_type> &)) {slave.add_listener(object, method);}

    private:
        std::string name;
        axis_bus bus;
        axis_slave<data_type, dest_type, user_type> slave;
    };

    // the beat of a bus, and the one of a stream whose data is a word
    extern template class axis_source<>;
    extern template class axis_sink<>;
    extern template class axis_source<uint32_t, uint32_t, uint32_t>;
    extern template class axis_sink<uint32_t, uint32_t, uint32_t>;

}

#endif //SCTB_AXIS_ENDPOINTS_HPP
