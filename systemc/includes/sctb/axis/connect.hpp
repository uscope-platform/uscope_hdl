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

#ifndef SCTB_AXIS_CONNECT_HPP
#define SCTB_AXIS_CONNECT_HPP

#include <systemc.h>

#include <string>

#include "sctb/axis/bus.hpp"

namespace sctb {

    /// Connects the ports of a model to a bus. The ports are looked up by name, they are the ones called
    /// <stream>_valid, <stream>_ready, <stream>_data, <stream>_dest, <stream>_user and <stream>_tlast,
    /// and they can point in either direction
    void connect_stream(axis_bus &bus, const sc_module &model, const std::string &stream);

}

#endif //SCTB_AXIS_CONNECT_HPP
