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

#include "sctb/axi/connect.hpp"

#include <string>

#include "../port_bind.hpp"

namespace sctb {

    void connect_axi(axi_bus &bus, const sc_module &model, const std::string &name) {
        // the control signals are one bit
        bind_port<bool>(bus, model, name + "_awvalid", bus.awvalid);
        bind_port<bool>(bus, model, name + "_awready", bus.awready);
        bind_port<bool>(bus, model, name + "_awlock", bus.awlock);
        bind_port<bool>(bus, model, name + "_wvalid", bus.wvalid);
        bind_port<bool>(bus, model, name + "_wready", bus.wready);
        bind_port<bool>(bus, model, name + "_wlast", bus.wlast);
        bind_port<bool>(bus, model, name + "_bvalid", bus.bvalid);
        bind_port<bool>(bus, model, name + "_bready", bus.bready);
        bind_port<bool>(bus, model, name + "_arvalid", bus.arvalid);
        bind_port<bool>(bus, model, name + "_arready", bus.arready);
        bind_port<bool>(bus, model, name + "_arlock", bus.arlock);
        bind_port<bool>(bus, model, name + "_rvalid", bus.rvalid);
        bind_port<bool>(bus, model, name + "_rready", bus.rready);
        bind_port<bool>(bus, model, name + "_rlast", bus.rlast);

        // the addresses and the data are as wide as the interface, from 1 to 64 bits
        bind_port<uint64_t, uint32_t, uint16_t, uint8_t, bool>(bus, model, name + "_awaddr", bus.awaddr);
        bind_port<uint64_t, uint32_t, uint16_t, uint8_t, bool>(bus, model, name + "_araddr", bus.araddr);
        bind_port<uint64_t, uint32_t, uint16_t, uint8_t, bool>(bus, model, name + "_wdata", bus.wdata);
        bind_port<uint64_t, uint32_t, uint16_t, uint8_t, bool>(bus, model, name + "_rdata", bus.rdata);

        // the others are at most 32 bits
        const auto narrow = [&](const std::string &port, sc_signal<uint32_t> &signal) {
            bind_port<uint32_t, uint16_t, uint8_t, bool>(bus, model, name + "_" + port, signal);
        };
        narrow("awid", bus.awid);
        narrow("awlen", bus.awlen);
        narrow("awsize", bus.awsize);
        narrow("awburst", bus.awburst);
        narrow("awcache", bus.awcache);
        narrow("awprot", bus.awprot);
        narrow("awqos", bus.awqos);
        narrow("awregion", bus.awregion);
        narrow("awuser", bus.awuser);
        narrow("wstrb", bus.wstrb);
        narrow("wuser", bus.wuser);
        narrow("bid", bus.bid);
        narrow("bresp", bus.bresp);
        narrow("buser", bus.buser);
        narrow("arid", bus.arid);
        narrow("arlen", bus.arlen);
        narrow("arsize", bus.arsize);
        narrow("arburst", bus.arburst);
        narrow("arcache", bus.arcache);
        narrow("arprot", bus.arprot);
        narrow("arqos", bus.arqos);
        narrow("arregion", bus.arregion);
        narrow("aruser", bus.aruser);
        narrow("rid", bus.rid);
        narrow("rresp", bus.rresp);
        narrow("ruser", bus.ruser);
    }

}
