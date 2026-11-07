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

#include "sctb/progress.hpp"

#include "sctb/report.hpp"

namespace sctb {

    progress::progress(int64_t total_steps, int step_percent) : total(total_steps), step(step_percent), next(step_percent) {}

    void progress::update(int64_t done) {
        while(next <= 100 && done * 100 >= total * next) print(done);
    }

    void progress::finish() {
        while(next <= 100) print(total);
    }

    void progress::print(int64_t done) {
        auto &report = reporter::instance();
        report.info(format("%3d%% (%lld of %lld, %lld errors)", next, static_cast<long long>(done),
                           static_cast<long long>(total), static_cast<long long>(report.get_errors())));
        next += step;
    }

}
