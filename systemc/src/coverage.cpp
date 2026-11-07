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

#include "sctb/coverage.hpp"

#include "sctb/report.hpp"

namespace sctb {

    coverpoint::coverpoint(const std::string &point_name, const std::vector<std::string> &bin_names) :
        name(point_name), bins(bin_names), hits(bin_names.size(), 0) {}

    bool coverpoint::report() const {
        auto &printer = reporter::instance();
        bool all_hit = true;
        printer.info("coverage " + name);
        for(size_t i = 0; i < bins.size(); i++){
            printer.info(format("  %-12s %lld", bins[i].c_str(), static_cast<long long>(hits[i])));
            if(hits[i] == 0) all_hit = false;
        }
        return all_hit;
    }

    bool covergroup::report() const {
        bool all_hit = true;
        for(auto point : points){
            if(!point->report()) all_hit = false;
        }
        if(!all_hit) reporter::instance().error("coverage is incomplete, some bins were never hit");
        return all_hit;
    }

}
