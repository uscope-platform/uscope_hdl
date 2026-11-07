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

#include "sctb/axis/bus.hpp"

#include "sctb/report.hpp"

namespace sctb {

    axis_bus::axis_bus(const std::string &name, uint32_t width) :
        valid((name + "_valid").c_str()),
        ready((name + "_ready").c_str()),
        data((name + "_data").c_str()),
        dest((name + "_dest").c_str()),
        user((name + "_user").c_str()),
        tlast((name + "_tlast").c_str()),
        data_bits(width) {
        if(width < 1 || width > 64) {
            SC_REPORT_FATAL("sctb", format("the data of the stream %s is %u bits wide, it has to be from 1 to 64", name.c_str(), width).c_str());
        }
    }

}
