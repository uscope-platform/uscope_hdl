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

#ifndef SCTB_AXI_MONITOR_HPP
#define SCTB_AXI_MONITOR_HPP

#include <systemc.h>

#include <deque>
#include <functional>
#include <string>
#include <vector>

#include "sctb/axi/bus.hpp"
#include "sctb/axi/transaction.hpp"
#include "sctb/clocking.hpp"

namespace sctb {

    /// Watches an AXI4 interface and hands its listeners the transactions as wholes, which is what a scoreboard
    /// wants to see. It only looks, so it can be on either side of the device, and on an interface that the testbench
    /// does not drive.
    ///
    /// A write is reported when its response is taken, with the address from the aw channel, the beats from the w
    /// channel and the response from b. A read is reported when its last beat is taken, with the address from ar and the
    /// beats from r. The channels of a transaction are matched in the order they arrive, which is what a master and a
    /// slave that keep their transactions in order do. The things that can not be a valid transaction, such as a
    /// response nobody asked for or a burst of a different length than the address said, are reported as errors
    class axi_monitor {
    public:
        axi_monitor(const std::string &name, axi_bus &bus, const clock &clk);

        void add_write_listener(std::function<void(const axi_write &)> listener) {write_listeners.push_back(listener);}
        void add_read_listener(std::function<void(const axi_read &)> listener) {read_listeners.push_back(listener);}
        /// The listener is a member function of an object
        template<typename T>
        void add_write_listener(T &object, void (T::*method)(const axi_write &)) {add_write_listener(std::bind(method, &object, std::placeholders::_1));}
        template<typename T>
        void add_read_listener(T &object, void (T::*method)(const axi_read &)) {add_read_listener(std::bind(method, &object, std::placeholders::_1));}

    private:
        struct address_beat {
            uint32_t id;
            uint64_t address;
            uint32_t beats;
        };
        struct data_burst {
            std::vector<uint64_t> data;
            std::vector<uint32_t> strobe;
        };

        void sample();
        void sample_write();
        void sample_read();
        void error(const std::string &message) const;

        std::string name;
        axi_bus &bus;
        std::vector<std::function<void(const axi_write &)>> write_listeners;
        std::vector<std::function<void(const axi_read &)>> read_listeners;

        // the write address and the write data arrive in either order, they are put together once both are there
        std::deque<address_beat> write_addresses;
        std::deque<data_burst> write_bursts;
        data_burst current_burst;
        std::deque<axi_write> awaiting_response;

        std::deque<address_beat> read_addresses;
        axi_read current_read;
        bool reading = false;
    };

}

#endif //SCTB_AXI_MONITOR_HPP
