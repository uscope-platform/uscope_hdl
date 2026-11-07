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

#ifndef SCTB_OPTIONS_HPP
#define SCTB_OPTIONS_HPP

#include <cstdint>
#include <map>
#include <string>
#include <vector>

namespace sctb {

    /// The command line of a test. An option is --name=value, or --name alone, everything else is a positional argument
    class options {
    public:
        options(int argc, char *argv[]);

        bool has(const std::string &name) const {return named.count(name) != 0;}
        /// The fallback when the option is not there
        std::string get(const std::string &name, const std::string &fallback = "") const;
        int64_t get_integer(const std::string &name, int64_t fallback) const;

        const std::vector<std::string> &get_positional() const {return positional;}
        int64_t get_positional_integer(size_t index, int64_t fallback) const;

    private:
        std::map<std::string, std::string> named;
        std::vector<std::string> positional;
    };

}

#endif //SCTB_OPTIONS_HPP
