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

#ifndef SCTB_AXI_ENDPOINTS_HPP
#define SCTB_AXI_ENDPOINTS_HPP

#include <systemc.h>

#include <cstdint>
#include <string>

#include "sctb/axi/bus.hpp"
#include "sctb/axi/connect.hpp"
#include "sctb/axi/master.hpp"
#include "sctb/axi/slave.hpp"
#include "sctb/clocking.hpp"

namespace sctb {

    /// The master end of an AXI interface of the device: the bus and a master that drives it, which is all the
    /// plumbing an interface of a device that is a slave needs
    class axi_driver {
    public:
        axi_driver(const std::string &name, const clock &clk, uint32_t data_bits = 32, uint32_t addr_bits = 32, uint32_t id_bits = 1,
                   uint32_t user_bits = 1);

        /// Connects the ports of the model called <name>_awvalid and so on to the bus
        void connect(const sc_module &model) {connect_axi(bus, model, name);}

        const axi_bus &get_bus() const {return bus;}
        axi_bus &get_bus() {return bus;}
        axi_master &get_master() {return master;}

    private:
        std::string name;
        axi_bus bus;
        axi_master master;
    };

    /// The slave end of an AXI interface of the device, for a device that is an AXI master: the bus and a slave that
    /// answers it. The counterpart of axis_sink
    class axi_responder {
    public:
        axi_responder(const std::string &name, const clock &clk, uint32_t data_bits = 32, uint32_t addr_bits = 32, uint32_t id_bits = 1,
                      uint32_t user_bits = 1);

        /// Connects the ports of the model called <name>_awvalid and so on to the bus
        void connect(const sc_module &model) {connect_axi(bus, model, name);}

        const axi_bus &get_bus() const {return bus;}
        axi_bus &get_bus() {return bus;}
        axi_slave &get_slave() {return slave;}

    private:
        std::string name;
        axi_bus bus;
        axi_slave slave;
    };

}

#endif //SCTB_AXI_ENDPOINTS_HPP
