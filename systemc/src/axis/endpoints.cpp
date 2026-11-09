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

#include "sctb/axis/endpoints.hpp"

namespace sctb {

    axis_source::axis_source(const std::string &stream, const clock &clk, uint32_t data_bits, uint32_t dest_bits, uint32_t user_bits) :
        name(stream), bus(stream, data_bits, dest_bits, user_bits), master(bus, clk) {}

    axis_sink::axis_sink(const std::string &stream, const clock &clk, uint32_t data_bits, double ready_probability, uint64_t seed,
                         uint32_t dest_bits, uint32_t user_bits) :
        name(stream), bus(stream, data_bits, dest_bits, user_bits), slave(stream + "_slave", bus, clk, ready_probability, seed) {}

}
