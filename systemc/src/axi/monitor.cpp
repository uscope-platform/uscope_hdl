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

#include "sctb/axi/monitor.hpp"

#include "sctb/report.hpp"
#include "sctb/run.hpp"

namespace sctb {

    namespace {

        axi_response worst(axi_response a, axi_response b) {
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

    axi_monitor::axi_monitor(const std::string &monitor_name, axi_bus &axi, const clock &clk) : name(monitor_name), bus(axi) {
        spawn_every_cycle(monitor_name, clk, *this, &axi_monitor::sample);
    }

    void axi_monitor::error(const std::string &message) const {
        reporter::instance().error(format("[%s] %s", name.c_str(), message.c_str()));
    }

    // the values read are the ones from before the clock edge, like the ones the RTL sees
    void axi_monitor::sample() {
        sample_write();
        sample_read();
    }

    void axi_monitor::sample_write() {
        if(bus.awvalid.read() && bus.awready.read()) {
            write_addresses.push_back({bus.awid.read(), bus.awaddr.read(), bus.awlen.read() + 1u});
        }
        if(bus.wvalid.read() && bus.wready.read()) {
            current_burst.data.push_back(bus.wdata.read());
            current_burst.strobe.push_back(bus.wstrb.read());
            if(bus.wlast.read()) {
                write_bursts.push_back(std::move(current_burst));
                current_burst = data_burst();
            }
        }
        // the address and the data of a write are put together as soon as both are there
        while(!write_addresses.empty() && !write_bursts.empty()) {
            const address_beat address = write_addresses.front();
            data_burst burst = std::move(write_bursts.front());
            write_addresses.pop_front();
            write_bursts.pop_front();
            if(burst.data.size() != address.beats) {
                error(format("write at 0x%llx: the w channel carried %zu beats, awlen says %u", static_cast<unsigned long long>(address.address),
                             burst.data.size(), address.beats));
            }
            axi_write write;
            write.id = address.id;
            write.address = address.address;
            write.data = std::move(burst.data);
            write.strobe = std::move(burst.strobe);
            awaiting_response.push_back(std::move(write));
        }
        if(bus.bvalid.read() && bus.bready.read()) {
            if(awaiting_response.empty()) {
                error("write response (b channel) with no write waiting for one");
                return;
            }
            axi_write write = std::move(awaiting_response.front());
            awaiting_response.pop_front();
            write.response = static_cast<axi_response>(bus.bresp.read() & 3);
            for(auto &listener : write_listeners) listener(write);
        }
    }

    void axi_monitor::sample_read() {
        if(bus.arvalid.read() && bus.arready.read()) {
            read_addresses.push_back({bus.arid.read(), bus.araddr.read(), bus.arlen.read() + 1u});
        }
        if(bus.rvalid.read() && bus.rready.read()) {
            if(!reading) {
                if(read_addresses.empty()) {
                    error("read data (r channel) with no read waiting for it");
                    return;
                }
                const address_beat address = read_addresses.front();
                read_addresses.pop_front();
                current_read = axi_read();
                current_read.id = address.id;
                current_read.address = address.address;
                current_read.beats = address.beats;
                reading = true;
            }
            current_read.data.push_back(bus.rdata.read());
            current_read.response = worst(current_read.response, static_cast<axi_response>(bus.rresp.read() & 3));
            if(bus.rlast.read()) {
                if(current_read.data.size() != current_read.beats) {
                    error(format("read at 0x%llx: the r channel carried %zu beats, arlen says %u", static_cast<unsigned long long>(current_read.address),
                                 current_read.data.size(), current_read.beats));
                }
                reading = false;
                for(auto &listener : read_listeners) listener(current_read);
            }
        }
    }

}
