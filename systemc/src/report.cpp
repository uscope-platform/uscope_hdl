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

#include "sctb/report.hpp"

#include <cstdarg>
#include <cstdio>

namespace sctb {

    std::string format(const char *fmt, ...) {
        va_list args;
        va_start(args, fmt);
        va_list args_copy;
        va_copy(args_copy, args);
        const int length = std::vsnprintf(nullptr, 0, fmt, args);
        va_end(args);

        std::string text(length > 0 ? length : 0, '\0');
        std::vsnprintf(text.data(), text.size() + 1, fmt, args_copy);
        va_end(args_copy);
        return text;
    }

    std::string hex(uint64_t value, int digits) {
        return format("%0*llx", digits, static_cast<unsigned long long>(value));
    }

    reporter &reporter::instance() {
        static reporter the_reporter;
        return the_reporter;
    }

    void reporter::info(const std::string &message) const {
        std::printf("%s\n", message.c_str());
        std::fflush(stdout);
    }

    void reporter::error(const std::string &message) {
        errors++;
        if(errors <= max_printed_errors) {
            std::printf("ERROR: %s\n", message.c_str());
        } else if(errors == max_printed_errors + 1) {
            std::printf("ERROR: further errors are not printed\n");
        }
    }

}
