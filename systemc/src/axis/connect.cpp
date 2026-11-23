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

#include "sctb/axis/connect.hpp"

#include <string>

#include "../port_bind.hpp"

namespace sctb {

    void connect_stream(axis_bus &bus, const sc_module &model, const std::string &stream) {
        // the control signals are one bit
        bind_port<bool>(bus, model, stream + "_valid", bus.valid);
        bind_port<bool>(bus, model, stream + "_ready", bus.ready);
        bind_port<bool>(bus, model, stream + "_tlast", bus.tlast);
        // the others are as wide as the stream, from 1 to 64 bits for the data and 32 for dest and user
        bind_port<uint64_t, uint32_t, uint16_t, uint8_t, bool>(bus, model, stream + "_data", bus.data);
        bind_port<uint32_t, uint16_t, uint8_t, bool>(bus, model, stream + "_dest", bus.dest);
        bind_port<uint32_t, uint16_t, uint8_t, bool>(bus, model, stream + "_user", bus.user);
    }

}
