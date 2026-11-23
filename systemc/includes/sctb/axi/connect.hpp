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

#ifndef SCTB_AXI_CONNECT_HPP
#define SCTB_AXI_CONNECT_HPP

#include <systemc.h>

#include <string>

#include "sctb/axi/bus.hpp"

namespace sctb {

    /// Connects the ports of a model to a bus. The ports are looked up by name, they are the signals of the
    /// interface in lower case with the name of the interface in front: <name>_awvalid, <name>_awaddr, <name>_wdata,
    /// <name>_rready and so on, 44 in all, and they can point in either direction. A port can be narrower than the
    /// signal that is bound to it, as long as the values that go through it fit
    void connect_axi(axi_bus &bus, const sc_module &model, const std::string &interface_name);

}

#endif //SCTB_AXI_CONNECT_HPP
