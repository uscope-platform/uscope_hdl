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

#include "sctb/axi/transaction.hpp"

#include "sctb/report.hpp"

namespace sctb {

    namespace {

        std::string address_text(uint64_t address) {return format("0x%llx", static_cast<unsigned long long>(address));}

        /// What differs in the data of two transactions: the number of beats, or the first beat that is not the same and
        /// how many are. The transaction is named by the caller, as "write at 0x2b0" or "read of 12 beats at 0x2b0"
        std::string compare_beats(const std::string &which, const char *what, const std::vector<uint64_t> &expected, const std::vector<uint64_t> &actual) {
            if(expected.size() != actual.size()) {
                return format("%s: %zu beats of %s, expected %zu", which.c_str(), actual.size(), what, expected.size());
            }
            size_t first = expected.size();
            size_t different = 0;
            for(size_t beat = 0; beat < expected.size(); beat++){
                if(expected[beat] == actual[beat]) continue;
                if(first == expected.size()) first = beat;
                different++;
            }
            if(different == 0) return {};
            return format("%s: %s of beat %zu is 0x%llx, expected 0x%llx (%zu of %zu beats differ)", which.c_str(), what, first,
                          static_cast<unsigned long long>(actual[first]), static_cast<unsigned long long>(expected[first]), different, expected.size());
        }

    }

    std::string compare(const axi_write &expected, const axi_write &actual) {
        const std::string which = "write at " + address_text(expected.address);
        if(expected.address != actual.address) {
            return format("write: address is %s, expected %s", address_text(actual.address).c_str(), address_text(expected.address).c_str());
        }
        if(expected.id != actual.id) return format("%s: id is %u, expected %u", which.c_str(), actual.id, expected.id);
        std::string difference = compare_beats(which, "data", expected.data, actual.data);
        if(!difference.empty()) return difference;
        for(size_t beat = 0; beat < expected.strobe.size() && beat < actual.strobe.size(); beat++){
            if(expected.strobe[beat] != actual.strobe[beat]) {
                return format("%s: strobe of beat %zu is 0x%x, expected 0x%x", which.c_str(), beat, actual.strobe[beat], expected.strobe[beat]);
            }
        }
        if(expected.strobe.size() != actual.strobe.size()) {
            return format("%s: %zu strobes, expected %zu", which.c_str(), actual.strobe.size(), expected.strobe.size());
        }
        if(expected.response != actual.response) {
            return format("%s: response is %s, expected %s", which.c_str(), to_string(actual.response), to_string(expected.response));
        }
        return {};
    }

    std::string compare(const axi_read &expected, const axi_read &actual) {
        const std::string which = format("read of %u beats at %s", expected.beats, address_text(expected.address).c_str());
        if(expected.address != actual.address) {
            return format("read: address is %s, expected %s", address_text(actual.address).c_str(), address_text(expected.address).c_str());
        }
        if(expected.id != actual.id) return format("%s: id is %u, expected %u", which.c_str(), actual.id, expected.id);
        if(expected.beats != actual.beats) return format("%s: the address asked for %u beats", which.c_str(), actual.beats);
        const std::string difference = compare_beats(which, "data", expected.data, actual.data);
        if(!difference.empty()) return difference;
        if(expected.response != actual.response) {
            return format("%s: response is %s, expected %s", which.c_str(), to_string(actual.response), to_string(expected.response));
        }
        return {};
    }

}
