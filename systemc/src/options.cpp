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

#include <algorithm>
#include <cstdio>
#include <cstdlib>

namespace sctb {

    namespace {

        /// The name the test was run as, without the folders it is in
        std::string program_name(const char *path) {
            const std::string full = path == nullptr ? "" : path;
            const size_t slash = full.find_last_of('/');
            return slash == std::string::npos ? full : full.substr(slash + 1);
        }

        // the options of the library, the ones a test does not have to do anything for
        const std::vector<help_entry> &library_options() {
            static const std::vector<help_entry> entries = {
                {"--trace=<file>", "write the waveform to file, FST format"},
                {"--trace-start=<cycle>", "the first cycle that is written, 0 by default"},
                {"--trace-cycles=<cycles>", "how many cycles are written, all of them by default"},
                {"--help, -h", "print this menu and exit"}};
            return entries;
        }

        /// Writes a list of entries lined up in two columns
        std::string table(const std::vector<help_entry> &entries) {
            size_t width = 0;
            for(const auto &entry : entries) width = std::max(width, entry.name.size());

            std::string text;
            for(const auto &entry : entries) {
                text += "  " + entry.name + std::string(width - entry.name.size() + 3, ' ') + entry.description + "\n";
            }
            return text;
        }

    }

    options::options(int argc, char *argv[], std::initializer_list<help_entry> arguments) {
        bool asked_for_help = false;
        for(int i = 1; i < argc; i++){
            const std::string argument = argv[i];
            if(argument == "--help" || argument == "-h") {
                asked_for_help = true;
                continue;
            }
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
        if(asked_for_help) {
            print_help(program_name(argc > 0 ? argv[0] : ""), arguments);
            std::exit(EXIT_SUCCESS);
        }
    }

    void options::print_help(const std::string &program, std::initializer_list<help_entry> arguments) {
        std::string text = "Usage: " + program;
        for(const auto &entry : arguments) text += " [" + entry.name + "]";
        text += " [options]\n";

        if(arguments.size() != 0) {
            text += "\nArguments:\n" + table(std::vector<help_entry>(arguments));
        }
        text += "\nOptions:\n" + table(library_options());

        std::fputs(text.c_str(), stdout);
        std::fflush(stdout);
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
