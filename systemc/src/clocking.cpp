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

#include "sctb/clocking.hpp"

namespace sctb {

    // the clock starts low, so the first rising edge is half a period in
    clock::clock(const char *name, sc_time clock_period) : period(clock_period), clk(name, clock_period, 0.5, SC_ZERO_TIME, false) {}

    void clock::wait_cycles(int64_t cycles) const {
        for(int64_t i = 0; i < cycles; i++){
            wait(posedge());
        }
    }

    void reset_sequence(sc_signal<bool> &reset_n, const clock &clk, int64_t cycles) {
        reset_n.write(false);
        clk.wait_cycles(cycles);
        reset_n.write(true);
    }

}
