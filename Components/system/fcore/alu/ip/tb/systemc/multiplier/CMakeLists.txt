# Copyright 2026 Filippo Savi
# Author: Filippo Savi <filssavi@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# cmake -S . -B build && cmake --build build && ./build/test [number of vectors]
cmake_minimum_required(VERSION 3.20)

# the simulation is much faster with optimizations, which a configure without a build type does not have
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

project(fcore_multiplier_ip_tb CXX)

set(COMPONENTS ${CMAKE_CURRENT_LIST_DIR}/../../../../../../..)

find_package(verilator REQUIRED)
add_subdirectory(${COMPONENTS}/../systemc sctb)

add_executable(test test.cpp)
target_link_libraries(test PRIVATE sctb)
target_include_directories(test PRIVATE ${CMAKE_CURRENT_LIST_DIR}/..)

# interfaces_no_timing.sv is interfaces.sv without the tasks that need the timing support of Verilator
# Verilator defines VERILATOR, which makes fcore_multiplier_ip a model built from the conversion modules
verilate(test SYSTEMC
    TOP_MODULE fcore_multiplier_ip_shim
    PREFIX Vfcore_multiplier_ip_shim
    SOURCES
        ${COMPONENTS}/Common/interfaces_no_timing.sv
        ${COMPONENTS}/system/floating_point_ip/fp32_to_fp64/rtl/fp_fp32_to_fp64.sv
        ${COMPONENTS}/system/floating_point_ip/fp64_to_fp32/rtl/fp_fp64_to_fp32.sv
        ${CMAKE_CURRENT_LIST_DIR}/../../../fcore_multiplier_ip.sv
        ${CMAKE_CURRENT_LIST_DIR}/fcore_multiplier_ip_shim.sv
    VERILATOR_ARGS --no-timing -Wno-fatal -Wno-lint -Wno-style)
