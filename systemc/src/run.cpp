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

#include "sctb/run.hpp"

#include "sctb/report.hpp"

namespace sctb {

    void init(double resolution, sc_time_unit unit) {
        sc_set_time_resolution(resolution, unit);
    }

    void spawn(const std::string &name, std::function<void()> body) {
        sc_spawn(body, name.c_str());
    }

    void spawn_every_cycle(const std::string &name, const clock &clk, std::function<void()> body) {
        spawn_on_event(name, clk.posedge(), body);
    }

    void spawn_on_event(const std::string &name, const sc_event &event, std::function<void()> body) {
        sc_spawn_options options;
        options.spawn_method();
        options.set_sensitivity(&event);
        options.dont_initialize();
        sc_spawn(body, name.c_str(), &options);
    }

    void finish() {
        sc_stop();
    }

    int run(sc_time timeout) {
        auto &report = reporter::instance();
        if(timeout == SC_ZERO_TIME) {
            sc_start();
        } else {
            sc_start(timeout);
        }
        if(sc_get_status() != SC_STOPPED) report.error("the test timed out before it finished");

        report.info(report.passed() ? "PASSED" : format("FAILED, %lld errors", static_cast<long long>(report.get_errors())));
        return report.get_exit_code();
    }

}
