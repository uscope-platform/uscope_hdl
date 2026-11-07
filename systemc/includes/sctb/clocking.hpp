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

#ifndef SCTB_CLOCKING_HPP
#define SCTB_CLOCKING_HPP

#include <systemc.h>

#include <cstdint>

namespace sctb {

    /// The testbench clock. Everything synchronous waits for its rising edge, like the tasks of the verilog BFMs
    class clock {
    public:
        explicit clock(const char *name, sc_time clock_period = sc_time(10, SC_NS));

        sc_signal_in_if<bool> &get_signal() {return clk;}
        const sc_signal_in_if<bool> &get_signal() const {return clk;}
        const sc_event &posedge() const {return clk.posedge_event();}
        sc_time get_period() const {return period;}

        /// Waits for a number of rising edges, can only be called from a thread
        void wait_cycles(int64_t cycles) const;

    private:
        sc_time period;
        sc_clock clk;
    };

    /// Active low reset, asserted for a number of cycles and then released. Can only be called from a thread
    void reset_sequence(sc_signal<bool> &reset_n, const clock &clk, int64_t cycles = 4);

}

#endif //SCTB_CLOCKING_HPP
