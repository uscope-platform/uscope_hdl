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

#ifndef SCTB_COVERAGE_HPP
#define SCTB_COVERAGE_HPP

#include <cstdint>
#include <string>
#include <vector>

namespace sctb {

    /// Functional coverage of a value that falls in one of a list of named bins. The classification is up to
    /// the test, which calls hit() with the number of the bin
    class coverpoint {
    public:
        coverpoint(const std::string &name, const std::vector<std::string> &bin_names);

        void hit(size_t bin) {hits[bin]++;}

        /// Prints how many times each bin was hit, returns whether all of them were
        bool report() const;

    private:
        std::string name;
        std::vector<std::string> bins;
        std::vector<int64_t> hits;
    };

    /// A set of coverpoints. A bin that was never hit is an error, the test did not look at that case
    class covergroup {
    public:
        void add(const coverpoint &point) {points.push_back(&point);}

        bool report() const;

    private:
        std::vector<const coverpoint *> points;
    };

}

#endif //SCTB_COVERAGE_HPP
