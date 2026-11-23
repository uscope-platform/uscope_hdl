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

#ifndef SCTB_AXI_BUS_HPP
#define SCTB_AXI_BUS_HPP

#include <systemc.h>

#include <cstdint>
#include <memory>
#include <string>
#include <vector>

namespace sctb {

    /// The response of a transfer, the value of bresp and rresp
    enum class axi_response : uint8_t {okay = 0, exokay = 1, slverr = 2, decerr = 3};

    const char *to_string(axi_response response);

    /// The signals of an AXI4 interface, the five channels: the write address (aw), the write data (w), the write
    /// response (b), the read address (ar) and the read data (r). Counterpart of the AXI interface in Common.
    /// The signals have a fixed size, the data and the address are 64 bits and the others 32, and the widths of the
    /// interface are how many of those bits are used, the ones above them are zero. The ports of the model can be
    /// narrower than the signals, connect_axi adapts them
    class axi_bus {
    public:
        explicit axi_bus(const std::string &name, uint32_t data_bits = 32, uint32_t addr_bits = 32, uint32_t id_bits = 1, uint32_t user_bits = 1);

        const std::string &get_name() const {return name;}
        uint32_t get_data_bits() const {return data_bits;}
        uint32_t get_addr_bits() const {return addr_bits;}
        uint32_t get_id_bits() const {return id_bits;}
        uint32_t get_user_bits() const {return user_bits;}

        /// Keeps a port view alive as long as the bus. connect_axi binds a port that is narrower than a signal to a
        /// view of it, and a port only holds a pointer to what it is bound to, so the view has to outlive the call.
        /// The views have a type for each width of port, so they are held without their type
        void adopt_port_view(std::shared_ptr<void> view) {port_views.push_back(std::move(view));}

        // write address
        sc_signal<uint32_t> awid;
        sc_signal<uint64_t> awaddr;
        sc_signal<uint32_t> awlen;
        sc_signal<uint32_t> awsize;
        sc_signal<uint32_t> awburst;
        sc_signal<bool> awlock;
        sc_signal<uint32_t> awcache;
        sc_signal<uint32_t> awprot;
        sc_signal<uint32_t> awqos;
        sc_signal<uint32_t> awregion;
        sc_signal<uint32_t> awuser;
        sc_signal<bool> awvalid;
        sc_signal<bool> awready;
        // write data
        sc_signal<uint64_t> wdata;
        sc_signal<uint32_t> wstrb;
        sc_signal<bool> wlast;
        sc_signal<uint32_t> wuser;
        sc_signal<bool> wvalid;
        sc_signal<bool> wready;
        // write response
        sc_signal<uint32_t> bid;
        sc_signal<uint32_t> bresp;
        sc_signal<uint32_t> buser;
        sc_signal<bool> bvalid;
        sc_signal<bool> bready;
        // read address
        sc_signal<uint32_t> arid;
        sc_signal<uint64_t> araddr;
        sc_signal<uint32_t> arlen;
        sc_signal<uint32_t> arsize;
        sc_signal<uint32_t> arburst;
        sc_signal<bool> arlock;
        sc_signal<uint32_t> arcache;
        sc_signal<uint32_t> arprot;
        sc_signal<uint32_t> arqos;
        sc_signal<uint32_t> arregion;
        sc_signal<uint32_t> aruser;
        sc_signal<bool> arvalid;
        sc_signal<bool> arready;
        // read data
        sc_signal<uint32_t> rid;
        sc_signal<uint64_t> rdata;
        sc_signal<uint32_t> rresp;
        sc_signal<bool> rlast;
        sc_signal<uint32_t> ruser;
        sc_signal<bool> rvalid;
        sc_signal<bool> rready;

    private:
        std::string name;
        uint32_t data_bits;
        uint32_t addr_bits;
        uint32_t id_bits;
        uint32_t user_bits;
        std::vector<std::shared_ptr<void>> port_views;
    };

}

#endif //SCTB_AXI_BUS_HPP
