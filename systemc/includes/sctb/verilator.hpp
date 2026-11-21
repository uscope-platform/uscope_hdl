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

#ifndef SCTB_VERILATOR_HPP
#define SCTB_VERILATOR_HPP

#include <cstdio>
#include <memory>

#include "verilated_fst_sc.h"

#include "sctb/trace.hpp"

namespace sctb {

    // the signals inside the device are the only part of the waveform that is the business of the simulator, so this
    // is the only place that knows about it, and the rest of the library does not need its headers
    template<typename Model>
    void trace::add_dut(Model &model, int depth) {
        if(!is_enabled()) return;
        device_file = file + ".dut";
        // the tracer is made now, while the testbench is being elaborated, as it registers itself with the kernel, and
        // given the model when the run starts, as the model is elaborated only by then
        auto tracer = std::make_shared<VerilatedFstSc>();
        start_tracer = [this, &model, tracer, depth] {
            Verilated::traceEverOn(true);
            model.trace(tracer.get(), depth);
            tracer->open(device_file.c_str());
        };
        stop_tracer = [this, tracer] {
            tracer->close();
            merge_dut();
            std::remove(device_file.c_str());
        };
    }

}

#endif //SCTB_VERILATOR_HPP
