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

#include "sctb/axis/slave.hpp"

#include "sctb/run.hpp"

namespace sctb {

    axis_slave::axis_slave(const std::string &name, axis_bus &stream, const clock &clk, double ready_probability, uint64_t seed) :
        monitor(name + "_monitor", stream, clk), bus(stream), probability(ready_probability), rng(seed), chance(0.0, 1.0) {
        bus.ready.write(probability >= 1.0);
        if(probability < 1.0) {
            spawn_every_cycle(name + "_ready", clk, *this, &axis_slave::drive_ready);
        }
    }

    void axis_slave::drive_ready() {bus.ready.write(chance(rng) < probability);}

}
