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

#include "sctb/axi/slave.hpp"

#include "sctb/run.hpp"

namespace sctb {

    namespace {

        uint64_t byte_mask(uint32_t strobe, uint32_t bytes) {
            uint64_t mask = 0;
            for(uint32_t byte = 0; byte < bytes; byte++){
                if(strobe & (1u << byte)) mask |= uint64_t(0xff) << (8 * byte);
            }
            return mask;
        }

    }

    axi_slave::axi_slave(const std::string &name, axi_bus &stream, const clock &clk) : bus(stream), bytes(stream.get_data_bits() / 8) {
        bus.awready.write(false);
        bus.wready.write(false);
        bus.bvalid.write(false);
        bus.arready.write(false);
        bus.rvalid.write(false);
        spawn_every_cycle(name, clk, *this, &axi_slave::step);
    }

    uint64_t axi_slave::peek(uint64_t address) const {
        const auto found = memory.find(address & ~uint64_t(bytes - 1));
        return found == memory.end() ? 0 : found->second;
    }

    void axi_slave::poke(uint64_t address, uint64_t data) {memory[address & ~uint64_t(bytes - 1)] = data;}

    uint64_t axi_slave::beat_address(uint64_t start, uint32_t beat) const {
        // the first beat can be anywhere in its word, the next ones are on the words that follow
        return (start & ~uint64_t(bytes - 1)) + uint64_t(beat) * bytes;
    }

    void axi_slave::step() {
        step_write();
        step_read();
    }

    // the values read are the ones from before the clock edge, like the ones the RTL sees, and what is written is seen at the next one
    void axi_slave::step_write() {
        switch(write_state) {
            case write_phase::address:
                if(bus.awvalid.read() && bus.awready.read()) {
                    current_write = axi_write();
                    current_write.id = bus.awid.read();
                    current_write.address = bus.awaddr.read();
                    write_answer = answer;
                    write_state = write_phase::data;
                }
                break;
            case write_phase::data:
                if(bus.wvalid.read() && bus.wready.read()) {
                    current_write.data.push_back(bus.wdata.read());
                    current_write.strobe.push_back(bus.wstrb.read());
                    if(bus.wlast.read()) {
                        if(write_answer == axi_response::okay) {
                            for(uint32_t beat = 0; beat < current_write.data.size(); beat++){
                                const uint64_t where = beat_address(current_write.address, beat);
                                const uint64_t mask = byte_mask(current_write.strobe[beat], bytes);
                                memory[where] = (peek(where) & ~mask) | (current_write.data[beat] & mask);
                            }
                        }
                        current_write.response = write_answer;
                        for(auto &listener : write_listeners) listener(current_write);
                        write_wait = latency;
                        write_state = write_phase::response;
                    }
                }
                break;
            case write_phase::response:
                if(bus.bvalid.read() && bus.bready.read()) write_state = write_phase::address;
                else if(write_wait > 0) write_wait--;
                break;
        }
        bus.awready.write(write_state == write_phase::address && !is_hung);
        bus.wready.write(write_state == write_phase::data && !is_hung);
        bus.bvalid.write(write_state == write_phase::response && write_wait == 0 && !is_hung);
        bus.bresp.write(static_cast<uint32_t>(write_answer));
        bus.bid.write(current_write.id);
    }

    void axi_slave::step_read() {
        switch(read_state) {
            case read_phase::address:
                if(bus.arvalid.read() && bus.arready.read()) {
                    current_read.id = bus.arid.read();
                    current_read.address = bus.araddr.read();
                    current_read.beats = bus.arlen.read() + 1;
                    current_read.data.clear();
                    current_read.response = answer;
                    read_answer = answer;
                    read_beat = 0;
                    read_wait = latency;
                    read_state = read_phase::data;
                    for(auto &listener : read_listeners) listener(current_read);
                }
                break;
            case read_phase::data:
                if(bus.rvalid.read() && bus.rready.read()) {
                    read_beat++;
                    if(read_beat == current_read.beats) read_state = read_phase::address;
                } else if(read_wait > 0) {
                    read_wait--;
                }
                break;
        }
        const bool sending = read_state == read_phase::data && read_wait == 0 && !is_hung;
        bus.arready.write(read_state == read_phase::address && !is_hung);
        bus.rvalid.write(sending);
        bus.rid.write(current_read.id);
        bus.rresp.write(static_cast<uint32_t>(read_answer));
        bus.rlast.write(read_beat + 1 == current_read.beats);
        bus.rdata.write(read_answer == axi_response::okay && read_state == read_phase::data ? peek(beat_address(current_read.address, read_beat)) : 0);
    }

}
