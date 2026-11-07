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
#include <string>

namespace sctb {

    /// One transfer
    struct axis_beat {
        uint64_t data = 0;
        uint32_t dest = 0;
        uint32_t user = 0;
        bool tlast = false;

        /// dest, user and tlast, what a device that only transforms the data has to carry through
        bool same_sideband(const axis_beat &other) const {return dest == other.dest && user == other.user && tlast == other.tlast;}
    };

    /// The signals of a stream, the interface. The data signal is always 64 bits, the width of the stream is how many
    /// of them are used: the ones above it are zero, and the waveform shows only the ones below
    class axis_bus {
    public:
        explicit axis_bus(const std::string &name, uint32_t data_bits = 64);

        uint32_t get_data_bits() const {return data_bits;}

        sc_signal<bool> valid;
        sc_signal<bool> ready;
        sc_signal<uint64_t> data;
        sc_signal<uint32_t> dest;
        sc_signal<uint32_t> user;
        sc_signal<bool> tlast;

    private:
        uint32_t data_bits;
    };

}

#endif //SCTB_AXIS_BUS_HPP
