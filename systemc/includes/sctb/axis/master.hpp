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

#ifndef SCTB_AXIS_MASTER_HPP
#define SCTB_AXIS_MASTER_HPP

#include <systemc.h>

#include <cstdint>

#include "sctb/axis/bus.hpp"
#include "sctb/clocking.hpp"

namespace sctb {

    /// Drives a bus. The calls block, so they can be made from a thread like the tasks of axis_BFM are called
    /// from an initial block. The definitions are in the library, only the default beat is built
    template <typename data_type = uint64_t, typename dest_type = uint32_t, typename user_type = uint32_t>
    class axis_master {
    public:
        axis_master(axis_bus &bus, const clock &clk);

        /// Returns when the beat has been accepted. Consecutive calls send one beat per cycle as long as the
        /// slave is ready
        void write(const axis_beat<data_type, dest_type, user_type> &beat);
        void write(uint64_t data, uint32_t dest = 0, uint32_t user = 0, bool tlast = false);

        /// Puts the beat on the bus for the next clock edge and returns at once, whatever ready is. It is for a
        /// stream without back pressure, and for putting a beat on several streams in the same cycle: the caller
        /// waits for the edge, for example with clock::wait_cycles(1)
        void put(const axis_beat<data_type, dest_type, user_type> &beat);
        void put(uint64_t data, uint32_t dest = 0, uint32_t user = 0, bool tlast = false);

        /// Leaves the bus idle for a number of cycles
        void idle(int64_t cycles = 1);

    private:
        void drive_idle();

        axis_bus &bus;
        const clock &clk;
    };

    extern template class axis_master<>;

}

#endif //SCTB_AXIS_MASTER_HPP
