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

#ifndef SCTB_REPORT_HPP
#define SCTB_REPORT_HPP

#include <cstdint>
#include <string>

namespace sctb {

    /// printf into a string
    std::string format(const char *fmt, ...) __attribute__((format(printf, 1, 2)));

    /// Hexadecimal with a fixed number of digits
    std::string hex(uint64_t value, int digits);

    /// Collects the verdict of a test, every checker reports to it. The exit code of the simulation is whether
    /// anything was reported.
    class reporter {
    public:
        static reporter &instance();

        /// Only the first errors are printed, all of them are counted
        void set_max_printed_errors(int64_t max) {max_printed_errors = max;}

        void info(const std::string &message) const;
        void error(const std::string &message);

        int64_t get_errors() const {return errors;}
        bool passed() const {return errors == 0;}
        int get_exit_code() const {return passed() ? 0 : 1;}

    private:
        reporter() = default;

        int64_t errors = 0;
        int64_t max_printed_errors = 10;
    };

}

#endif //SCTB_REPORT_HPP
