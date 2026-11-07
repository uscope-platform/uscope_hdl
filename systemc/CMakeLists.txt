#  Copyright 2026 University of Nottingham
#  Author: Filippo Savi <filssavi@gmail.com>
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

# The sctb testbench library: add_subdirectory() this and link sctb
cmake_minimum_required(VERSION 3.20)

find_package(SystemCLanguage REQUIRED)

# the writer of the waveform files, it is plain C and has no build system for CMake so the three sources it needs are compiled here.
# The commit is pinned: what is built does not change when the repository does
enable_language(C)
find_package(ZLIB REQUIRED)
include(FetchContent)
FetchContent_Declare(libfst
        GIT_REPOSITORY https://github.com/gtkwave/libfst
        GIT_TAG bf53e719f099729cedc6e4e5d5400f79bd80c610)
FetchContent_MakeAvailable(libfst)

add_library(sctb_fst STATIC
        ${libfst_SOURCE_DIR}/src/fstapi.c
        ${libfst_SOURCE_DIR}/src/fastlz.c
        ${libfst_SOURCE_DIR}/src/lz4.c
)
target_include_directories(sctb_fst SYSTEM PUBLIC ${libfst_SOURCE_DIR}/src)
target_compile_definitions(sctb_fst PRIVATE HAVE_FSEEKO)
# it is somebody else's code, its warnings are not ours to fix
target_compile_options(sctb_fst PRIVATE -w)
target_link_libraries(sctb_fst PUBLIC ZLIB::ZLIB)

add_library(sctb STATIC
        src/axis/bus.cpp
        src/axis/connect.cpp
        src/axis/endpoints.cpp
        src/axis/master.cpp
        src/axis/monitor.cpp
        src/axis/slave.cpp
        src/checks.cpp
        src/clocking.cpp
        src/coverage.cpp
        src/options.cpp
        src/progress.cpp
        src/report.cpp
        src/run.cpp
        src/scoreboard.cpp
        src/trace.cpp
)
target_include_directories(sctb PUBLIC ${CMAKE_CURRENT_LIST_DIR}/includes)
target_compile_features(sctb PUBLIC cxx_std_17)
target_link_libraries(sctb PUBLIC SystemC::systemc)
target_link_libraries(sctb PRIVATE sctb_fst)
