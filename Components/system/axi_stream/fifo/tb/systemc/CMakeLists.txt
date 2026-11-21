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

project(axis_fifo_tb CXX)

set(COMPONENTS ${CMAKE_CURRENT_LIST_DIR}/../../../../..)

find_package(verilator REQUIRED)
add_subdirectory(${COMPONENTS}/../systemc sctb)

add_executable(test axis_fifo_tb.cpp)
target_link_libraries(test PRIVATE sctb)

# interfaces_no_timing.sv is interfaces.sv without the tasks that need the timing support of Verilator
verilate(test SYSTEMC
    TOP_MODULE axis_fifo_shim
    PREFIX Vaxis_fifo_shim
    TRACE_FST
    SOURCES
        ${COMPONENTS}/Common/interfaces_no_timing.sv
        ${CMAKE_CURRENT_LIST_DIR}/../../rtl/axis_fifo.sv
        ${CMAKE_CURRENT_LIST_DIR}/axis_fifo_shim.sv
    VERILATOR_ARGS --no-timing -Wno-fatal -Wno-lint -Wno-style)

# the tracer writes FST through lz4, which Verilator links by name
find_path(LZ4_INCLUDE_DIR lz4.h REQUIRED)
find_library(LZ4_LIBRARY lz4 REQUIRED)
get_filename_component(LZ4_LIBRARY_DIR ${LZ4_LIBRARY} DIRECTORY)
target_include_directories(test PRIVATE ${LZ4_INCLUDE_DIR})
target_link_directories(test PRIVATE ${LZ4_LIBRARY_DIR})
