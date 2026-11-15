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
#include <initializer_list>
#include <map>
#include <string>
#include <vector>

namespace sctb {

    /// One line of the help menu
    struct help_entry {
        std::string name;
        std::string description;
    };

    /// The command line of a test. An option is --name=value, or --name alone, everything else is a positional
    /// argument. --help, or -h, prints the menu of the test and exits, so every test has one
    class options {
    public:
        /// The arguments the test takes on top of the number of vectors, which every test has under that name.
        /// Calling the test with --help lists them with the options of the library
        options(int argc, char *argv[],
                std::initializer_list<help_entry> arguments = {{"vectors", "how many vectors to send, the test has a default"}});

        /// The menu, for --help and for a test that wants to print it itself
        static void print_help(const std::string &program,
                               std::initializer_list<help_entry> arguments = {{"vectors", "how many vectors to send, the test has a default"}});

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
