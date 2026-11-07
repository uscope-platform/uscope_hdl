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

#include "sctb/axis/master.hpp"

#include "sctb/report.hpp"

namespace sctb {

    axis_master::axis_master(axis_bus &stream, const clock &clock_source) : bus(stream), clk(clock_source) {
        drive_idle();
    }

    void axis_master::put(const axis_beat &beat) {
        const uint32_t bits = bus.get_data_bits();
        if(bits < 64 && (beat.data >> bits) != 0) {
            reporter::instance().error(format("[%s] the data %s does not fit the %u bits of the stream", bus.data.basename(),
                                              hex(beat.data, 16).c_str(), bits));
        }
        bus.data.write(beat.data);
        bus.dest.write(beat.dest);
        bus.user.write(beat.user);
        bus.tlast.write(beat.tlast);
        bus.valid.write(true);
    }

    void axis_master::put(uint64_t data, uint32_t dest, uint32_t user, bool tlast) {
        put({data, dest, user, tlast});
    }

    void axis_master::write(const axis_beat &beat) {
        put(beat);
        do {
            wait(clk.posedge());
        } while(!bus.ready.read());
        // when the next write follows right away this is overwritten in the same instant, and valid stays high
        bus.valid.write(false);
    }

    void axis_master::write(uint64_t data, uint32_t dest, uint32_t user, bool tlast) {
        write({data, dest, user, tlast});
    }

    void axis_master::idle(int64_t cycles) {
        drive_idle();
        clk.wait_cycles(cycles);
    }

    void axis_master::drive_idle() {
        bus.valid.write(false);
        bus.data.write(0);
        bus.dest.write(0);
        bus.user.write(0);
        bus.tlast.write(false);
    }

}
