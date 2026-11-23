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

#ifndef SCTB_AXIS_BUS_HPP
#define SCTB_AXIS_BUS_HPP

#include <systemc.h>

#include <cstdint>
#include <memory>
#include <string>
#include <vector>

namespace sctb {

    /// One transfer. The types default to the ones of the signals of axis_bus: a beat is normally just axis_beat
    template <typename data_type = uint64_t, typename dest_type = uint32_t, typename user_type = uint32_t>
    struct axis_beat {
        data_type data = 0;
        dest_type dest = 0;
        user_type user = 0;
        bool tlast = false;

        /// dest, user and tlast, what a device that only transforms the data has to carry through
        bool same_sideband(const axis_beat &other) const {return dest == other.dest && user == other.user && tlast == other.tlast;}
    };

    /// The signals of a stream, the interface. The data signal is always 64 bits, and dest and user 32, the width of the
    /// stream is how many of them are used: the ones above it are zero, and the waveform shows only the ones below.
    /// The ports of the model can be narrower than the signals, connect_stream adapts them
    class axis_bus {
    public:
        explicit axis_bus(const std::string &name, uint32_t data_bits = 64, uint32_t dest_bits = 32, uint32_t user_bits = 32);

        uint32_t get_data_bits() const {return data_bits;}
        uint32_t get_dest_bits() const {return dest_bits;}
        uint32_t get_user_bits() const {return user_bits;}

        /// Keeps a port view alive as long as the bus. connect_stream binds a port that is narrower than a signal to a
        /// view of it, and a port only holds a pointer to what it is bound to, so the view has to outlive the call.
        /// The views have a type for each width of port, so they are held without their type
        void adopt_port_view(std::shared_ptr<void> view) {port_views.push_back(std::move(view));}

        sc_signal<bool> valid;
        sc_signal<bool> ready;
        sc_signal<uint64_t> data;
        sc_signal<uint32_t> dest;
        sc_signal<uint32_t> user;
        sc_signal<bool> tlast;

    private:
        uint32_t data_bits;
        uint32_t dest_bits;
        uint32_t user_bits;
        std::vector<std::shared_ptr<void>> port_views;
    };

}

#endif //SCTB_AXIS_BUS_HPP
