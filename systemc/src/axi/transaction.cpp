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

        std::string compare_beats(const char *what, const std::vector<uint64_t> &expected, const std::vector<uint64_t> &actual) {
            if(expected.size() != actual.size()) {
                return format("%s has %zu beats, expected %zu", what, actual.size(), expected.size());
            }
            for(size_t beat = 0; beat < expected.size(); beat++){
                if(expected[beat] != actual[beat]) {
                    return format("%s of beat %zu is %s, expected %s", what, beat, hex(actual[beat], 16).c_str(), hex(expected[beat], 16).c_str());
                }
            }
            return {};
        }

    }

    std::string compare(const axi_write &expected, const axi_write &actual) {
        if(expected.id != actual.id) return format("write id is %u, expected %u", actual.id, expected.id);
        if(expected.address != actual.address) {
            return format("write address is %s, expected %s", hex(actual.address, 16).c_str(), hex(expected.address, 16).c_str());
        }
        std::string difference = compare_beats("write data", expected.data, actual.data);
        if(!difference.empty()) return format("write at %s: %s", hex(expected.address, 16).c_str(), difference.c_str());
        if(expected.strobe != actual.strobe) return format("write at %s: the strobes are different", hex(expected.address, 16).c_str());
        if(expected.response != actual.response) {
            return format("write at %s: response is %s, expected %s", hex(expected.address, 16).c_str(), to_string(actual.response), to_string(expected.response));
        }
        return {};
    }

    std::string compare(const axi_read &expected, const axi_read &actual) {
        if(expected.id != actual.id) return format("read id is %u, expected %u", actual.id, expected.id);
        if(expected.address != actual.address) {
            return format("read address is %s, expected %s", hex(actual.address, 16).c_str(), hex(expected.address, 16).c_str());
        }
        if(expected.beats != actual.beats) {
            return format("read at %s: %u beats, expected %u", hex(expected.address, 16).c_str(), actual.beats, expected.beats);
        }
        const std::string difference = compare_beats("read data", expected.data, actual.data);
        if(!difference.empty()) return format("read at %s: %s", hex(expected.address, 16).c_str(), difference.c_str());
        if(expected.response != actual.response) {
            return format("read at %s: response is %s, expected %s", hex(expected.address, 16).c_str(), to_string(actual.response), to_string(expected.response));
        }
        return {};
    }

}
