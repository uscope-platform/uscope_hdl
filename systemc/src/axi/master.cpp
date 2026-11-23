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

#include "sctb/axi/master.hpp"

#include <algorithm>

#include "sctb/report.hpp"

namespace sctb {

    namespace {

        constexpr uint32_t burst_incr = 1;
        constexpr uint32_t max_beats = 256;
        constexpr uint64_t boundary = 4096;

        uint64_t mask_of(uint32_t bits) {return bits >= 64 ? ~uint64_t(0) : (uint64_t(1) << bits) - 1;}

        uint32_t log2_of(uint32_t value) {
            uint32_t result = 0;
            while((uint32_t(1) << result) < value) result++;
            return result;
        }

        axi_response worst(axi_response a, axi_response b) {
            // a decode error is worse than a slave error, which is worse than the rest
            const auto rank = [](axi_response response) {
                switch(response) {
                    case axi_response::decerr: return 3;
                    case axi_response::slverr: return 2;
                    case axi_response::exokay: return 1;
                    default: return 0;
                }
            };
            return rank(a) >= rank(b) ? a : b;
        }

    }

    axi_master::axi_master(axi_bus &axi, const clock &clock_source) :
        bus(axi), clk(clock_source), size(log2_of(axi.get_data_bits() / 8)) {
        drive_idle();
    }

    // the checks that the protocol has on a burst, and the ones that the interface has on the values
    bool axi_master::check_burst(const char *what, uint64_t address, uint32_t beats) const {
        const std::string &name = bus.get_name();
        if(beats < 1 || beats > max_beats) {
            reporter::instance().error(format("[%s] a %s of %u beats, a burst has from 1 to %u", name.c_str(), what, beats, max_beats));
            return false;
        }
        if((address & ~mask_of(bus.get_addr_bits())) != 0) {
            reporter::instance().error(format("[%s] the address %s of a %s does not fit the %u bits of the interface", name.c_str(),
                                              hex(address, 16).c_str(), what, bus.get_addr_bits()));
            return false;
        }
        const uint64_t bytes = uint64_t(beats) << size;
        if(address / boundary != (address + bytes - 1) / boundary) {
            reporter::instance().error(format("[%s] a %s of %u beats from %s crosses a 4 KB boundary", name.c_str(), what, beats,
                                              hex(address, 16).c_str()));
            return false;
        }
        return true;
    }

    axi_response axi_master::write(uint64_t address, uint64_t data, uint64_t strobe) {
        return write_burst(address, std::vector<uint64_t>{data}, strobe);
    }

    axi_response axi_master::write_burst(uint64_t address, const std::vector<uint64_t> &data, uint64_t strobe) {
        const uint32_t beats = static_cast<uint32_t>(data.size());
        if(!check_burst("write", address, beats)) return axi_response::slverr;
        const std::string &name = bus.get_name();
        const uint64_t data_mask = mask_of(bus.get_data_bits());
        const uint64_t strobe_mask = mask_of(bus.get_data_bits() / 8);
        for(uint64_t beat : data){
            if((beat & ~data_mask) != 0) {
                reporter::instance().error(format("[%s] the data %s does not fit the %u bits of the interface", name.c_str(),
                                                  hex(beat, 16).c_str(), bus.get_data_bits()));
                return axi_response::slverr;
            }
        }

        // the address and the first beat go out together, the device can take them in either order
        bus.awid.write(transaction_id);
        bus.awaddr.write(address);
        bus.awlen.write(beats - 1);
        bus.awsize.write(size);
        bus.awburst.write(burst_incr);
        bus.awuser.write(transaction_user);
        bus.awvalid.write(true);

        const auto drive_beat = [&](uint32_t index) {
            bus.wdata.write(data[index]);
            bus.wstrb.write(static_cast<uint32_t>(strobe & strobe_mask));
            bus.wlast.write(index == beats - 1);
            bus.wuser.write(transaction_user);
            bus.wvalid.write(true);
        };
        drive_beat(0);

        bool address_pending = true;
        uint32_t sent = 0;
        while(address_pending || sent < beats){
            wait(clk.posedge());
            // the values read are the ones from before the clock edge, like the ones the RTL sees
            if(address_pending && bus.awready.read()) {
                address_pending = false;
                bus.awvalid.write(false);
            }
            if(sent < beats && bus.wready.read()) {
                sent++;
                if(sent < beats) {
                    drive_beat(sent);
                } else {
                    bus.wvalid.write(false);
                    bus.wlast.write(false);
                }
            }
        }

        // the response comes after the last beat, ready is raised for it
        bus.bready.write(true);
        do {
            wait(clk.posedge());
        } while(!bus.bvalid.read());
        const auto response = static_cast<axi_response>(bus.bresp.read() & 3);
        bus.bready.write(false);
        return response;
    }

    axi_response axi_master::read(uint64_t address, uint64_t &data) {
        std::vector<uint64_t> beats;
        const axi_response response = read_burst(address, 1, beats);
        data = beats.empty() ? 0 : beats.front();
        return response;
    }

    axi_response axi_master::read_burst(uint64_t address, uint32_t beats, std::vector<uint64_t> &data) {
        data.clear();
        if(!check_burst("read", address, beats)) return axi_response::slverr;

        bus.arid.write(transaction_id);
        bus.araddr.write(address);
        bus.arlen.write(beats - 1);
        bus.arsize.write(size);
        bus.arburst.write(burst_incr);
        bus.aruser.write(transaction_user);
        bus.arvalid.write(true);
        // the data can come as soon as the address is taken, and nothing else is waited for
        bus.rready.write(true);

        axi_response response = axi_response::okay;
        bool address_pending = true;
        while(address_pending || data.size() < beats){
            wait(clk.posedge());
            if(address_pending && bus.arready.read()) {
                address_pending = false;
                bus.arvalid.write(false);
            }
            if(bus.rvalid.read()) {
                data.push_back(bus.rdata.read());
                response = worst(response, static_cast<axi_response>(bus.rresp.read() & 3));
                const bool last = data.size() == beats;
                if(bus.rlast.read() != last) {
                    reporter::instance().error(format("[%s] rlast is %d on beat %zu of %u", bus.get_name().c_str(), int(bus.rlast.read()),
                                                      data.size(), beats));
                }
            }
        }
        bus.rready.write(false);
        return response;
    }

    void axi_master::idle(int64_t cycles) {clk.wait_cycles(cycles);}

    void axi_master::drive_idle() {
        bus.awvalid.write(false);
        bus.wvalid.write(false);
        bus.wlast.write(false);
        bus.bready.write(false);
        bus.arvalid.write(false);
        bus.rready.write(false);
        bus.awaddr.write(0);
        bus.araddr.write(0);
        bus.wdata.write(0);
        bus.wstrb.write(0);
    }

}
