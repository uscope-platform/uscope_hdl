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

#include "sctb/options.hpp"

#include <cstdlib>

namespace sctb {

    options::options(int argc, char *argv[]) {
        for(int i = 1; i < argc; i++){
            const std::string argument = argv[i];
            if(argument.rfind("--", 0) != 0) {
                positional.push_back(argument);
                continue;
            }
            const size_t equals = argument.find('=');
            if(equals == std::string::npos) {
                named[argument.substr(2)] = "";
            } else {
                named[argument.substr(2, equals - 2)] = argument.substr(equals + 1);
            }
        }
    }

    std::string options::get(const std::string &name, const std::string &fallback) const {
        const auto found = named.find(name);
        return found == named.end() ? fallback : found->second;
    }

    int64_t options::get_integer(const std::string &name, int64_t fallback) const {
        const auto found = named.find(name);
        return found == named.end() ? fallback : std::atoll(found->second.c_str());
    }

    int64_t options::get_positional_integer(size_t index, int64_t fallback) const {
        return index < positional.size() ? std::atoll(positional[index].c_str()) : fallback;
    }

}
