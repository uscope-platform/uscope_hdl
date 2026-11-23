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

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <fstream>

#include "fstcpp/fstcpp_writer.h"

#include "sctb/report.hpp"
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

        /// The stage of the test: it does not follow a signal, the value is set by the test
        class stage_signal : public trace_variable {
        public:
            stage_signal(trace &owner, fst::Handle handle, const uint64_t &value) : trace_variable(owner, handle), value(value) {}

            uint64_t read() const override {return value;}

        private:
            const uint64_t &value;
        };

        // the power of ten of the time resolution, -9 for nanoseconds
        int get_timescale() {return static_cast<int>(std::lround(std::log10(sc_get_time_resolution().to_seconds())));}

    }

    trace::trace(const options &opts, const clock &clk) :
        file(opts.get("trace")), start(SC_ZERO_TIME), end(sc_max_time()) {
        if(!opts.has("trace")) return;

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
        instances().push_back(this);
    }

    trace::~trace() {
        auto &all = instances();
        all.erase(std::remove(all.begin(), all.end(), this), all.end());
        close_file();
        // the file of the device is merged into this one, so it can only be closed once this one is
        if(device_started) {
            device_started = false;
            stop_tracer();
        }
    }

    std::vector<trace *> &trace::instances() {
        static std::vector<trace *> all;
        return all;
    }

    void trace::close_file() {
        if(writer == nullptr) return;
        if(!begun) writer->upscope();
        writer->close();
        delete writer;
        writer = nullptr;
        // a window that never opened has no value in it, and a file without values also loses its signals, so it is
        // removed instead of left behind unreadable
        if(!begun) std::remove(file.c_str());
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

    void trace::define_stages(const std::vector<std::string> &names) {
        if(names.size() > 255) SC_REPORT_FATAL("sctb", "a test has up to 255 stages");
        stage_names = names;
        if(!is_enabled()) return;
        if(begun) SC_REPORT_FATAL("sctb", "the stages have to be defined before the test starts, the waveform is being written");

        // the value 0 is before the first stage, the stages follow it. The viewer shows the names, the table of the names
        // goes before the signal that uses it
        constexpr uint32_t bits = 8;
        std::vector<std::pair<std::string, std::string>> table = {{"none", std::string(bits, '0')}};
        for(size_t index = 0; index < names.size(); index++){
            std::string value(bits, '0');
            for(uint32_t bit = 0; bit < bits; bit++){
                if(((index + 1) >> bit) & 1) value[bits - 1 - bit] = '1';
            }
            table.emplace_back(names[index], value);
        }
        // the writer wants pointers to the text
        std::vector<std::pair<const char *, const char *>> entries;
        for(const auto &entry : table) entries.emplace_back(entry.first.c_str(), entry.second.c_str());
        const fst::EnumHandle names_table = writer->createEnumTable("test_stages", bits, entries);
        writer->emitEnumTableRef(names_table);
        const fst::Handle handle = writer->createVar(fst::Hierarchy::VarType::VCD_WIRE, fst::Hierarchy::VarDirection::IMPLICIT, bits, "test_stage", 0);
        variables.push_back(std::make_unique<stage_signal>(*this, handle, stage_value));
        stage_variable = variables.back().get();
    }

    void trace::stage(const std::string &name) {
        const auto found = std::find(stage_names.begin(), stage_names.end(), name);
        if(found == stage_names.end()) {
            reporter::instance().error(format("the stage %s was not given to define_stages", name.c_str()));
            return;
        }
        if(!is_enabled() || stage_variable == nullptr) return;
        stage_value = static_cast<uint64_t>(found - stage_names.begin()) + 1;
        record(*stage_variable);
    }

    void trace::add(const axi_bus &bus) {
        const auto control = [&](const sc_signal<bool> &signal) {add(signal.basename(), signal);};
        const auto field = [&](const sc_signal<uint32_t> &signal, uint32_t bits) {add(signal.basename(), signal, bits);};
        const uint32_t data_bits = bus.get_data_bits();
        const uint32_t addr_bits = bus.get_addr_bits();
        const uint32_t id_bits = bus.get_id_bits();
        const uint32_t user_bits = bus.get_user_bits();

        field(bus.awid, id_bits);
        add(bus.awaddr.basename(), bus.awaddr, addr_bits);
        field(bus.awlen, 8);
        field(bus.awsize, 3);
        field(bus.awburst, 2);
        control(bus.awlock);
        field(bus.awcache, 4);
        field(bus.awprot, 3);
        field(bus.awqos, 4);
        field(bus.awregion, 4);
        field(bus.awuser, user_bits);
        control(bus.awvalid);
        control(bus.awready);

        add(bus.wdata.basename(), bus.wdata, data_bits);
        field(bus.wstrb, data_bits / 8);
        control(bus.wlast);
        field(bus.wuser, user_bits);
        control(bus.wvalid);
        control(bus.wready);

        field(bus.bid, id_bits);
        field(bus.bresp, 2);
        field(bus.buser, user_bits);
        control(bus.bvalid);
        control(bus.bready);

        field(bus.arid, id_bits);
        add(bus.araddr.basename(), bus.araddr, addr_bits);
        field(bus.arlen, 8);
        field(bus.arsize, 3);
        field(bus.arburst, 2);
        control(bus.arlock);
        field(bus.arcache, 4);
        field(bus.arprot, 3);
        field(bus.arqos, 4);
        field(bus.arregion, 4);
        field(bus.aruser, user_bits);
        control(bus.arvalid);
        control(bus.arready);

        field(bus.rid, id_bits);
        add(bus.rdata.basename(), bus.rdata, data_bits);
        field(bus.rresp, 2);
        control(bus.rlast);
        field(bus.ruser, user_bits);
        control(bus.rvalid);
        control(bus.rready);
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

    // the model is elaborated only once the simulation starts, and its tracer can not be given to it after the first
    // dump, so it is set up by run() before the simulation goes on
    void trace::start_device() {
        if(device_started || !start_tracer) return;
        device_started = true;
        start_tracer();
    }

    // every signal has a value from the start of the window, so all of them are written when it opens
    void trace::begin_window() {
        writer->upscope();
        window_start = sc_time_stamp();
        emit_time();
        for(auto &variable : variables) {
            variable->dump(*writer);
        }
        begun = true;
        recording = true;
    }

}
