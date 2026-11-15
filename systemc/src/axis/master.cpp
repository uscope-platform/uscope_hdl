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

    template <typename data_type, typename dest_type, typename user_type>
    axis_master<data_type, dest_type, user_type>::axis_master(axis_bus &stream, const clock &clock_source) : bus(stream), clk(clock_source) {
        drive_idle();
    }

    template <typename data_type, typename dest_type, typename user_type>
    void axis_master<data_type, dest_type, user_type>::put(const axis_beat<data_type, dest_type, user_type> &beat) {
        const uint32_t bits = bus.get_data_bits();
        if(bits < 64 && (beat.data >> bits) != 0) {
            reporter::instance().error(format("[%s] the data %s does not fit the %u bits of the stream", bus.data.basename(),
                                              hex(beat.data, 16).c_str(), bits));
        }
        const uint32_t dest_bits = bus.get_dest_bits();
        if(dest_bits < 32 && (beat.dest >> dest_bits) != 0) {
            reporter::instance().error(format("[%s] the dest %s does not fit the %u bits of the stream", bus.dest.basename(),
                                              hex(beat.dest, 8).c_str(), dest_bits));
        }
        const uint32_t user_bits = bus.get_user_bits();
        if(user_bits < 32 && (beat.user >> user_bits) != 0) {
            reporter::instance().error(format("[%s] the user %s does not fit the %u bits of the stream", bus.user.basename(),
                                              hex(beat.user, 8).c_str(), user_bits));
        }
        bus.data.write(beat.data);
        bus.dest.write(beat.dest);
        bus.user.write(beat.user);
        bus.tlast.write(beat.tlast);
        bus.valid.write(true);
    }

    template <typename data_type, typename dest_type, typename user_type>
    void axis_master<data_type, dest_type, user_type>::put(uint64_t data, uint32_t dest, uint32_t user, bool tlast) {
        put({static_cast<data_type>(data), static_cast<dest_type>(dest), static_cast<user_type>(user), tlast});
    }

    template <typename data_type, typename dest_type, typename user_type>
    void axis_master<data_type, dest_type, user_type>::write(const axis_beat<data_type, dest_type, user_type> &beat) {
        put(beat);
        do {
            wait(clk.posedge());
        } while(!bus.ready.read());
        // when the next write follows right away this is overwritten in the same instant, and valid stays high
        bus.valid.write(false);
    }

    template <typename data_type, typename dest_type, typename user_type>
    void axis_master<data_type, dest_type, user_type>::write(uint64_t data, uint32_t dest, uint32_t user, bool tlast) {
        write({static_cast<data_type>(data), static_cast<dest_type>(dest), static_cast<user_type>(user), tlast});
    }

    template <typename data_type, typename dest_type, typename user_type>
    void axis_master<data_type, dest_type, user_type>::idle(int64_t cycles) {
        drive_idle();
        clk.wait_cycles(cycles);
    }

    template <typename data_type, typename dest_type, typename user_type>
    void axis_master<data_type, dest_type, user_type>::drive_idle() {
        bus.valid.write(false);
        bus.data.write(0);
        bus.dest.write(0);
        bus.user.write(0);
        bus.tlast.write(false);
    }

    template class axis_master<>;

}
