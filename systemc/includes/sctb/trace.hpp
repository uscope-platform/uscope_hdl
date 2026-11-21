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

#ifndef SCTB_TRACE_HPP
#define SCTB_TRACE_HPP

#include <systemc.h>

#include <cstdint>
#include <functional>
#include <memory>
#include <string>
#include <vector>

#include "sctb/axis/bus.hpp"
#include "sctb/axis/endpoints.hpp"
#include "sctb/clocking.hpp"
#include "sctb/options.hpp"

namespace fst {
    class Writer;
}

namespace sctb {

    class trace_variable;

    int run(sc_time timeout);

    /// Writes the signals that are added to it to a waveform file in the FST format. It is on when the command line
    /// has --trace=<file>. When it is off, add() returns immediately, so the signals can be listed in every test.
    /// --trace-start=<cycles> and --trace-cycles=<cycles> select the part of the simulation that is written, which
    /// is all of it by default
    class trace {
    public:
        /// The clock is always traced, and sets what a cycle is
        trace(const options &opts, const clock &clk);
        ~trace();
        trace(const trace &) = delete;
        trace &operator=(const trace &) = delete;

        bool is_enabled() const {return writer != nullptr;}

        /// Adds the signals inside the device to this waveform. The tracer of the model writes them to a file of its
        /// own, which is merged into this one when the run ends, so the test has nothing else to do. It does nothing
        /// when the trace is off. Defined in sctb/verilator.hpp, which needs the headers of the simulator
        template<typename Model>
        void add_dut(Model &model, int depth = 99);

        void add(const std::string &name, const sc_signal_in_if<bool> &signal);
        void add(const std::string &name, const sc_signal_in_if<uint32_t> &signal);
        void add(const std::string &name, const sc_signal_in_if<uint64_t> &signal);
        /// Only the lowest bits of the signal are written, for a value that is narrower than the signal that carries it
        void add(const std::string &name, const sc_signal_in_if<uint64_t> &signal, uint32_t bits);
        void add(const std::string &name, const sc_signal_in_if<uint32_t> &signal, uint32_t bits);

        /// The six signals of a stream, under the names they were given. The data, dest and user are written with the width of the stream
        void add(const axis_bus &bus);
        template<typename... beat_types>
        void add(const axis_source<beat_types...> &source) {add(source.get_bus());}
        template<typename... beat_types>
        void add(const axis_sink<beat_types...> &sink) {add(sink.get_bus());}

    private:
        friend class trace_variable;
        friend int run(sc_time timeout);

        template<typename T>
        void add_signal(const std::string &name, const sc_signal_in_if<T> &signal, uint32_t bits);

        // called by the variables when they change
        void record(const trace_variable &variable);
        void emit_time();
        // called every cycle, opens and closes the part of the simulation that is written
        void follow_window();
        void begin_window();
        void close_file();

        // the traces that are on, which run() gives their device to once the testbench is elaborated
        static std::vector<trace *> &instances();
        bool has_device() const {return static_cast<bool>(start_tracer);}
        // the device, whose tracer is opened when the run starts and merged into this file when it ends
        void start_device();
        void merge_dut();

        std::string file;
        fst::Writer *writer = nullptr;
        std::vector<std::unique_ptr<trace_variable>> variables;
        sc_time start;
        sc_time end;
        // the time the window opened, which is when the signals start being written
        sc_time window_start;
        // the file of the device, and the two steps of its tracer, which only sctb/verilator.hpp fills in
        std::string device_file;
        std::function<void()> start_tracer;
        std::function<void()> stop_tracer;
        bool device_started = false;
        bool begun = false;
        bool recording = false;
        bool time_written = false;
        uint64_t last_time = 0;
    };

}

#endif //SCTB_TRACE_HPP
