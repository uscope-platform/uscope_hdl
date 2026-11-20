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

#include "sctb/trace.hpp"

#include <cmath>
#include <fstream>

#include "fstcpp/fstcpp_writer.h"

#include "sctb/run.hpp"

namespace sctb {

    /// A signal in the file: where it is, how wide it is, and how to read it
    class trace_variable {
    public:
        trace_variable(trace &owner, fst::Handle handle) : owner(owner), handle(handle) {}
        virtual ~trace_variable() = default;

        virtual uint64_t read() const = 0;

        void dump(fst::Writer &writer) const {writer.emitValueChange(handle, read());}
        void changed() {owner.record(*this);}

    private:
        trace &owner;
        fst::Handle handle;
    };

    namespace {

        template<typename T>
        class traced_signal : public trace_variable {
        public:
            traced_signal(trace &owner, fst::Handle handle, const sc_signal_in_if<T> &signal) :
                trace_variable(owner, handle), signal(signal) {}

            uint64_t read() const override {return static_cast<uint64_t>(signal.read());}

        private:
            const sc_signal_in_if<T> &signal;
        };

        // the power of ten of the time resolution, -9 for nanoseconds
        int get_timescale() {return static_cast<int>(std::lround(std::log10(sc_get_time_resolution().to_seconds())));}

    }

    trace::trace(const options &opts, const clock &clk) : start(SC_ZERO_TIME), end(sc_max_time()) {
        if(!opts.has("trace")) return;

        const std::string file = opts.get("trace");
        // the writer does not say whether it could open the file, so it is checked here
        {
            const std::ofstream check(file, std::ios::binary);
            if(!check) SC_REPORT_FATAL("sctb", ("can not write the waveform file " + file).c_str());
        }
        writer = new fst::Writer(file);
        writer->setWriterPackType(fst::WriterPackType::LZ4);
        writer->setTimecale(static_cast<int8_t>(get_timescale()));
        writer->setWriter("sctb");
        writer->setScope(fst::Hierarchy::ScopeType::VCD_MODULE, "testbench", nullptr);

        start = clk.get_period() * static_cast<double>(opts.get_integer("trace-start", 0));
        const int64_t cycles = opts.get_integer("trace-cycles", 0);
        if(cycles > 0) end = start + clk.get_period() * static_cast<double>(cycles);

        add_signal("clock", clk.get_signal(), 1);
        spawn_every_cycle("trace_window", clk, *this, &trace::follow_window);
    }

    trace::~trace() {
        if(writer == nullptr) return;
        if(!begun) writer->upscope();
        writer->close();
        delete writer;
    }

    template<typename T>
    void trace::add_signal(const std::string &name, const sc_signal_in_if<T> &signal, uint32_t bits) {
        if(!is_enabled()) return;
        const fst::Handle handle = writer->createVar(fst::Hierarchy::VarType::VCD_WIRE,
                                                    fst::Hierarchy::VarDirection::IMPLICIT, bits, name, 0);
        variables.push_back(std::make_unique<traced_signal<T>>(*this, handle, signal));
        trace_variable &variable = *variables.back();
        spawn_on_event("trace_" + name, signal.value_changed_event(), variable, &trace_variable::changed);
    }

    void trace::add(const std::string &name, const sc_signal_in_if<bool> &signal) {add_signal(name, signal, 1);}
    void trace::add(const std::string &name, const sc_signal_in_if<uint32_t> &signal) {add_signal(name, signal, 32);}
    void trace::add(const std::string &name, const sc_signal_in_if<uint64_t> &signal) {add_signal(name, signal, 64);}
    void trace::add(const std::string &name, const sc_signal_in_if<uint64_t> &signal, uint32_t bits) {add_signal(name, signal, bits);}

    void trace::add(const std::string &name, const sc_signal_in_if<uint32_t> &signal, uint32_t bits) {add_signal(name, signal, bits);}

    void trace::add(const axis_bus &bus) {
        add(bus.valid.basename(), bus.valid);
        add(bus.ready.basename(), bus.ready);
        add(bus.data.basename(), bus.data, bus.get_data_bits());
        add(bus.dest.basename(), bus.dest, bus.get_dest_bits());
        add(bus.user.basename(), bus.user, bus.get_user_bits());
        add(bus.tlast.basename(), bus.tlast);
    }

    void trace::record(const trace_variable &variable) {
        if(!recording) return;
        emit_time();
        variable.dump(*writer);
    }

    void trace::emit_time() {
        const uint64_t now = sc_time_stamp().value();
        if(time_written && now == last_time) return;
        writer->emitTimeChange(now);
        last_time = now;
        time_written = true;
    }

    void trace::follow_window() {
        const sc_time now = sc_time_stamp();
        if(!begun && now >= start) {
            begin_window();
        } else if(recording && now >= end) {
            recording = false;
        }
    }

    // every signal has a value from the start of the window, so all of them are written when it opens
    void trace::begin_window() {
        writer->upscope();
        emit_time();
        for(auto &variable : variables) {
            variable->dump(*writer);
        }
        begun = true;
        recording = true;
    }

}
