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

#include "sctb/axis/monitor.hpp"

#include "sctb/run.hpp"

namespace sctb {

    template <typename data_type, typename dest_type, typename user_type>
    axis_monitor<data_type, dest_type, user_type>::axis_monitor(const std::string &name, axis_bus &stream, const clock &clk) : bus(stream) {
        spawn_every_cycle(name, clk, *this, &axis_monitor::sample);
    }

    // the values read are the ones from before the clock edge, like the ones the RTL sees
    template <typename data_type, typename dest_type, typename user_type>
    void axis_monitor<data_type, dest_type, user_type>::sample() {
        if(!bus.valid.read() || !bus.ready.read()) return;
        const axis_beat<data_type, dest_type, user_type> beat = {static_cast<data_type>(bus.data.read()),
                                                                 static_cast<dest_type>(bus.dest.read()),
                                                                 static_cast<user_type>(bus.user.read()),
                                                                 bus.tlast.read()};
        for(auto &listener : listeners){
            listener(beat);
        }
    }

    template class axis_monitor<>;

}
