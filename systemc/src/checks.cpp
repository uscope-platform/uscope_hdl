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

#include "sctb/checks.hpp"

#include <cmath>

#include "sctb/report.hpp"

namespace sctb {

    void check_throughput(int64_t beats, sc_time elapsed, const clock &clk) {
        const int64_t cycles = std::llround(elapsed / clk.get_period());
        if(cycles <= beats + 2) return;
        reporter::instance().error(format("%lld beats took %lld cycles, the input stalled",
                                          static_cast<long long>(beats), static_cast<long long>(cycles)));
    }

}
