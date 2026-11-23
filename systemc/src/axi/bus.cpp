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


#include "sctb/axi/bus.hpp"

#include "sctb/report.hpp"

namespace sctb {

    const char *to_string(axi_response response) {
        switch(response) {
            case axi_response::okay: return "OKAY";
            case axi_response::exokay: return "EXOKAY";
            case axi_response::slverr: return "SLVERR";
            case axi_response::decerr: return "DECERR";
        }
        return "?";
    }

    axi_bus::axi_bus(const std::string &name, uint32_t data_width, uint32_t addr_width, uint32_t id_width, uint32_t user_width) :
        awid((name + "_awid").c_str()),
        awaddr((name + "_awaddr").c_str()),
        awlen((name + "_awlen").c_str()),
        awsize((name + "_awsize").c_str()),
        awburst((name + "_awburst").c_str()),
        awlock((name + "_awlock").c_str()),
        awcache((name + "_awcache").c_str()),
        awprot((name + "_awprot").c_str()),
        awqos((name + "_awqos").c_str()),
        awregion((name + "_awregion").c_str()),
        awuser((name + "_awuser").c_str()),
        awvalid((name + "_awvalid").c_str()),
        awready((name + "_awready").c_str()),
        wdata((name + "_wdata").c_str()),
        wstrb((name + "_wstrb").c_str()),
        wlast((name + "_wlast").c_str()),
        wuser((name + "_wuser").c_str()),
        wvalid((name + "_wvalid").c_str()),
        wready((name + "_wready").c_str()),
        bid((name + "_bid").c_str()),
        bresp((name + "_bresp").c_str()),
        buser((name + "_buser").c_str()),
        bvalid((name + "_bvalid").c_str()),
        bready((name + "_bready").c_str()),
        arid((name + "_arid").c_str()),
        araddr((name + "_araddr").c_str()),
        arlen((name + "_arlen").c_str()),
        arsize((name + "_arsize").c_str()),
        arburst((name + "_arburst").c_str()),
        arlock((name + "_arlock").c_str()),
        arcache((name + "_arcache").c_str()),
        arprot((name + "_arprot").c_str()),
        arqos((name + "_arqos").c_str()),
        arregion((name + "_arregion").c_str()),
        aruser((name + "_aruser").c_str()),
        arvalid((name + "_arvalid").c_str()),
        arready((name + "_arready").c_str()),
        rid((name + "_rid").c_str()),
        rdata((name + "_rdata").c_str()),
        rresp((name + "_rresp").c_str()),
        rlast((name + "_rlast").c_str()),
        ruser((name + "_ruser").c_str()),
        rvalid((name + "_rvalid").c_str()),
        rready((name + "_rready").c_str()),
        name(name),
        data_bits(data_width),
        addr_bits(addr_width),
        id_bits(id_width),
        user_bits(user_width) {
        // the width of the data is a power of two number of bytes, as the size of a transfer is the log2 of it
        if(data_width < 8 || data_width > 64 || (data_width & (data_width - 1)) != 0) {
            SC_REPORT_FATAL("sctb", format("the data of the bus %s is %u bits wide, it has to be 8, 16, 32 or 64", name.c_str(), data_width).c_str());
        }
        if(addr_width < 1 || addr_width > 64) {
            SC_REPORT_FATAL("sctb", format("the address of the bus %s is %u bits wide, it has to be from 1 to 64", name.c_str(), addr_width).c_str());
        }
        if(id_width < 1 || id_width > 32) {
            SC_REPORT_FATAL("sctb", format("the id of the bus %s is %u bits wide, it has to be from 1 to 32", name.c_str(), id_width).c_str());
        }
        if(user_width < 1 || user_width > 32) {
            SC_REPORT_FATAL("sctb", format("the user of the bus %s is %u bits wide, it has to be from 1 to 32", name.c_str(), user_width).c_str());
        }
    }

}
