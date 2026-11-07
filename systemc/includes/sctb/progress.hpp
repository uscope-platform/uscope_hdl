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

#ifndef SCTB_PROGRESS_HPP
#define SCTB_PROGRESS_HPP

#include <cstdint>

namespace sctb {

    /// Prints a line every few percent of a long test, with the errors found so far
    class progress {
    public:
        explicit progress(int64_t total, int step_percent = 5);

        void update(int64_t done);
        /// Prints the lines that are still missing up to 100%
        void finish();

    private:
        void print(int64_t done);

        int64_t total;
        int step;
        int next;
    };

}

#endif //SCTB_PROGRESS_HPP
