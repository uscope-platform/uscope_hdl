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

#ifndef SCTB_AXI_MASTER_HPP
#define SCTB_AXI_MASTER_HPP

#include <systemc.h>

#include <cstdint>
#include <vector>

#include "sctb/axi/bus.hpp"
#include "sctb/clocking.hpp"

namespace sctb {

    /// Drives an AXI4 interface. The calls block until the transaction is over, so they can be made from a thread
    /// like the tasks of axi_full_bfm are called from an initial block. They return the response of the device, which
    /// for a burst is the worst of the beats. A read or a write of a burst is an INCR burst of the full width of the
    /// bus, which is the size of every beat.
    ///
    /// One transaction is in flight at a time per direction. The channels of a write and the ones of a read are
    /// independent, so a thread can write while another one reads, to run both at once
    class axi_master {
    public:
        axi_master(axi_bus &bus, const clock &clk);

        /// One beat. The strobe says which bytes of the data are written, all of them by default
        axi_response write(uint64_t address, uint64_t data, uint64_t strobe = ~uint64_t(0));
        /// The beats go to consecutive addresses, there can be from 1 to 256 and the burst can not cross a 4 KB boundary
        axi_response write_burst(uint64_t address, const std::vector<uint64_t> &data, uint64_t strobe = ~uint64_t(0));

        axi_response read(uint64_t address, uint64_t &data);
        /// Reads a number of beats, from 1 to 256, with the same limits as the write
        axi_response read_burst(uint64_t address, uint32_t beats, std::vector<uint64_t> &data);

        /// The id and the user that the next transactions carry, 0 by default
        void set_id(uint32_t id) {transaction_id = id;}
        void set_user(uint32_t user) {transaction_user = user;}

        /// Waits for a number of cycles without touching the bus, so it does not disturb a transaction of the other direction
        void idle(int64_t cycles = 1);

    private:
        bool check_burst(const char *what, uint64_t address, uint32_t beats) const;
        void drive_idle();

        axi_bus &bus;
        const clock &clk;
        uint32_t size;
        uint32_t transaction_id = 0;
        uint32_t transaction_user = 0;
    };

}

#endif //SCTB_AXI_MASTER_HPP
