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

#ifndef SCTB_AXI_SLAVE_HPP
#define SCTB_AXI_SLAVE_HPP

#include <systemc.h>

#include <cstdint>
#include <functional>
#include <map>
#include <string>
#include <vector>

#include "sctb/axi/bus.hpp"
#include "sctb/axi/transaction.hpp"
#include "sctb/clocking.hpp"

namespace sctb {

    /// Answers an AXI4 interface that the device drives: the counterpart of axi_master, and of axis_slave for a
    /// stream. It takes the addresses and the write data, answers the writes, and returns the data of a memory that
    /// starts as all zeros and holds what was written to it, which is what a test needs from whatever is behind the
    /// device. One write and one read are in flight at a time, the two directions are independent.
    ///
    /// What the slave does is set by the test while it runs: it can be told to go silent, to take longer to answer, or
    /// to answer with an error, which is how a test plays a slave that misbehaves
    class axi_slave {
    public:
        axi_slave(const std::string &name, axi_bus &bus, const clock &clk);

        /// While it is on, the slave raises no ready and no valid, as a slave that has hung does. What it has already
        /// accepted is kept, and the transaction goes on when it is turned off
        void set_hung(bool hung) {is_hung = hung;}
        /// Cycles between the last beat of a write and its response, and between a read address and the first beat. 1 by default
        void set_latency(uint32_t cycles) {latency = cycles;}
        /// The response of the transactions that come next, which is okay by default. An answer other than okay does not change the memory
        void set_response(axi_response response) {answer = response;}

        /// Called with the write once its last beat is in, and with the read request in the cycle its address is taken,
        /// so the data and the response of a read are not there yet. The axi_monitor has the whole transactions
        void add_write_listener(std::function<void(const axi_write &)> listener) {write_listeners.push_back(listener);}
        void add_read_listener(std::function<void(const axi_read &)> listener) {read_listeners.push_back(listener);}

        /// The memory, by the address of a beat of the width of the bus. Nothing is checked against its size, it is sparse
        uint64_t peek(uint64_t address) const;
        void poke(uint64_t address, uint64_t data);

    private:
        void step();
        void step_write();
        void step_read();
        uint64_t beat_address(uint64_t start, uint32_t beat) const;

        axi_bus &bus;
        uint32_t bytes;
        bool is_hung = false;
        uint32_t latency = 1;
        axi_response answer = axi_response::okay;
        std::map<uint64_t, uint64_t> memory;
        std::vector<std::function<void(const axi_write &)>> write_listeners;
        std::vector<std::function<void(const axi_read &)>> read_listeners;

        enum class write_phase {address, data, response};
        write_phase write_state = write_phase::address;
        axi_write current_write;
        axi_response write_answer = axi_response::okay;
        uint32_t write_wait = 0;

        enum class read_phase {address, data};
        read_phase read_state = read_phase::address;
        axi_read current_read;
        axi_response read_answer = axi_response::okay;
        uint32_t read_beat = 0;
        uint32_t read_wait = 0;
    };

}

#endif //SCTB_AXI_SLAVE_HPP
