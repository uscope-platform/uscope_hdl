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
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <map>
#include <string>
#include <vector>

// the reader of the waveform files. The writer only writes, so reading a file back, which merging does, needs this one
#include "fstapi.h"
#include "fstcpp/fstcpp_writer.h"

namespace sctb {

    namespace {

        /// A signal of the merged file: the handle it got there, and whether its values are floating point numbers
        struct merged_signal {
            fst::Handle handle;
            bool real;
        };

        /// Where the signals of a file went in the merged file, by the handle they had in the file they came from
        using merged_signals = std::map<fstHandle, merged_signal>;

        /// One value change, kept until both files have been read so that they can be written in time order
        struct value_change {
            uint64_t time;
            fst::Handle handle;
            bool real;
            std::string value;
        };

        /// The signals copied from one file
        struct hierarchy {
            merged_signals signals;
            uint32_t widest = 0;
        };

        fstReaderContext *open_reader(const std::string &file) {
            fstReaderContext *reader = fstReaderOpen(file.c_str());
            if(reader == nullptr) SC_REPORT_FATAL("sctb", ("can not read the waveform file " + file).c_str());
            fstReaderSetFacProcessMaskAll(reader);
            return reader;
        }

        bool is_real(fst::Hierarchy::VarType type) {
            return type == fst::Hierarchy::VarType::VCD_REAL || type == fst::Hierarchy::VarType::VCD_REAL_PARAMETER ||
                   type == fst::Hierarchy::VarType::VCD_REALTIME || type == fst::Hierarchy::VarType::SV_SHORTREAL;
        }

        /// Copies the signals of a file into the writer, in the scope that is open, and says where they went
        hierarchy copy_hierarchy(fst::Writer &writer, fstReaderContext *reader) {
            hierarchy result;
            if(!fstReaderIterateHierRewind(reader)) SC_REPORT_FATAL("sctb", "can not read the signals of a waveform file");

            while(const fstHier *entry = fstReaderIterateHier(reader)) {
                switch(entry->htyp) {
                    case FST_HT_SCOPE:
                        writer.setScope(static_cast<fst::Hierarchy::ScopeType>(entry->u.scope.typ),
                                        entry->u.scope.name, nullptr);
                        break;
                    case FST_HT_UPSCOPE:
                        writer.upscope();
                        break;
                    case FST_HT_VAR: {
                        // an alias is a second name of a signal that is already there, and it carries no values of its own
                        if(entry->u.var.is_alias || entry->u.var.length == 0) break;
                        const auto type = static_cast<fst::Hierarchy::VarType>(entry->u.var.typ);
                        const fst::Handle handle = writer.createVar(
                            type, static_cast<fst::Hierarchy::VarDirection>(entry->u.var.direction),
                            entry->u.var.length, entry->u.var.name, 0);
                        result.signals.emplace(entry->u.var.handle, merged_signal{handle, is_real(type)});
                        result.widest = std::max(result.widest, entry->u.var.length);
                        break;
                    }
                    default: // the attributes only describe the types, which the signals do not need
                        break;
                }
            }
            return result;
        }

        /// The value changes of a file inside the window, in the order they happen
        void read_changes(fstReaderContext *reader, const merged_signals &signals, uint64_t begin, uint64_t end,
                          std::vector<value_change> &changes) {
            struct collector {
                const merged_signals &signals;
                std::vector<value_change> &changes;
                uint64_t begin;
                uint64_t end;
            } context{signals, changes, begin, end};

            fstReaderIterBlocks2(
                reader,
                [](void *user, uint64_t time, fstHandle handle, const unsigned char *value) {
                    const collector &current = *static_cast<collector *>(user);
                    if(time < current.begin || time > current.end) return;
                    const auto signal = current.signals.find(handle);
                    if(signal == current.signals.end()) return;
                    current.changes.push_back(
                        {time, signal->second.handle, signal->second.real, reinterpret_cast<const char *>(value)});
                },
                nullptr, &context, nullptr);
        }

        void write(fst::Writer &writer, const value_change &change) {
            if(!change.real) {
                writer.emitValueChange(change.handle, change.value.c_str());
                return;
            }
            // the writer takes the bits of the number, and the reader gives them as text
            const double number = std::strtod(change.value.c_str(), nullptr);
            uint64_t bits = 0;
            std::memcpy(&bits, &number, sizeof(bits));
            writer.emitValueChange(change.handle, bits);
        }

    }

    void trace::merge_dut() {
        // the window never opened, so the testbench recorded nothing and there is no waveform to merge into
        if(!begun) return;

        fstReaderContext *main_reader = open_reader(file);
        fstReaderContext *other_reader = open_reader(device_file);

        const int8_t timescale = fstReaderGetTimescale(main_reader);
        if(fstReaderGetTimescale(other_reader) != timescale)
            SC_REPORT_FATAL("sctb", "the waveform of the device does not use the time resolution of the testbench");

        const std::string merged_file = file + ".merged";
        fst::Writer merged{merged_file};
        merged.setWriterPackType(fst::WriterPackType::LZ4);
        merged.setTimecale(timescale);
        merged.setWriter("sctb");

        const hierarchy main_hierarchy = copy_hierarchy(merged, main_reader);
        const hierarchy other_hierarchy = copy_hierarchy(merged, other_reader);

        std::vector<value_change> changes;
        read_changes(main_reader, main_hierarchy.signals, window_start.value(), end.value(), changes);
        // the values of the window start are written separately, as only the changes are in the file of the device
        read_changes(other_reader, other_hierarchy.signals, window_start.value() + 1, end.value(), changes);

        // every signal has a value when the window opens, so the ones that did not change yet are taken from the
        // file. A floating point number is written as text, which is longer than the signal is wide
        std::vector<char> value(std::max(other_hierarchy.widest + 1, 32u));
        for(const auto &[handle, signal] : other_hierarchy.signals) {
            if(fstReaderGetValueFromHandleAtTime(other_reader, window_start.value(), handle, value.data()) != nullptr) {
                changes.push_back({window_start.value(), signal.handle, signal.real, value.data()});
            }
        }

        std::stable_sort(changes.begin(), changes.end(),
                         [](const value_change &a, const value_change &b) { return a.time < b.time; });

        uint64_t time = 0;
        bool time_written = false;
        for(const value_change &change : changes) {
            if(!time_written || change.time != time) {
                merged.emitTimeChange(change.time);
                time = change.time;
                time_written = true;
            }
            write(merged, change);
        }

        merged.close();
        fstReaderClose(main_reader);
        fstReaderClose(other_reader);
        std::remove(file.c_str());
        if(std::rename(merged_file.c_str(), file.c_str()) != 0)
            SC_REPORT_FATAL("sctb", ("can not move the merged waveform to " + file).c_str());
    }

}
