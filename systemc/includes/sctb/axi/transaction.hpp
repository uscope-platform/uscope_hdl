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

#ifndef SCTB_AXI_TRANSACTION_HPP
#define SCTB_AXI_TRANSACTION_HPP

#include <cstdint>
#include <string>
#include <vector>

#include "sctb/axi/bus.hpp"

namespace sctb {

    /// A write as a whole: the address, the beats of the data with their strobes, and the response. This is what the
    /// monitor hands to its listeners, and what a scoreboard of writes holds
    struct axi_write {
        uint32_t id = 0;
        uint64_t address = 0;
        std::vector<uint64_t> data;
        std::vector<uint32_t> strobe;
        axi_response response = axi_response::okay;
    };

    /// A read as a whole: the address, the number of beats asked for, the data that came back and the response, which
    /// is the worst one of the beats. The slave hands its listeners the request alone, with no data
    struct axi_read {
        uint32_t id = 0;
        uint64_t address = 0;
        uint32_t beats = 0;
        std::vector<uint64_t> data;
        axi_response response = axi_response::okay;
    };

    /// What differs between two transactions, empty when they are the same. It is what the comparison of a scoreboard
    /// of transactions returns
    std::string compare(const axi_write &expected, const axi_write &actual);
    std::string compare(const axi_read &expected, const axi_read &actual);

}

#endif //SCTB_AXI_TRANSACTION_HPP
