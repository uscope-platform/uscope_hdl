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

#ifndef SCTB_PORT_VIEW_HPP
#define SCTB_PORT_VIEW_HPP

// Private to the library: used by port_bind.hpp only

#include <systemc.h>

#include <cstdint>
#include <string>
#include <type_traits>

#include "sctb/report.hpp"

namespace sctb {

    /// How a port of type T of a model sees a signal of type U that is wider than it.
    ///
    /// Verilator gives a port the narrowest of bool, uint8_t, uint16_t, uint32_t and uint64_t that holds it, while the
    /// signals of a bus have a fixed size. The port is bound to this instead of to the signal, and this forwards to
    /// the signal: there is no process and no delta cycle between the two, and the checks of the signal, such as the
    /// one that it has one writer, still apply because the writes reach it.
    ///   * a read gives the low bits of the signal. The ones that do not fit the port are reported, once
    ///   * a write is zero extended into the signal
    /// The edges are the only part of the interface of a signal that is there for a one bit signal only, so the view
    /// of a one bit port is port_view<bool> below and this is the view of every other port
    template<typename T, typename U>
    class port_view_base : public sc_signal_inout_if<T> {
        static_assert(sizeof(T) < sizeof(U) || std::is_same<T, bool>::value, "a port that is not narrower than the signal is bound to it directly");

    public:
        port_view_base(sc_signal<U> &signal, std::string port_name) : signal(signal), port_name(std::move(port_name)) {}

        // the interface of a signal
        const sc_event &value_changed_event() const override {return signal.value_changed_event();}
        const sc_event &default_event() const override {return signal.default_event();}
        bool event() const override {return signal.event();}
        const T &read() const override {
            const U value = signal.read();
            if(!fits(value)) report(value);
            cache = static_cast<T>(value & mask);
            return cache;
        }
        void write(const T &value) override {signal.write(static_cast<U>(value));}
        // part of the interface of SystemC 3.x, which the testbenches need, but not of the standard
        const T &get_data_ref() const override {return read();}

    protected:
        sc_signal<U> &signal;

    private:
        static constexpr uint32_t bits = std::is_same<T, bool>::value ? 1 : 8 * sizeof(T);
        static constexpr bool is_narrower = bits < 8 * sizeof(U);
        static constexpr U mask = is_narrower ? static_cast<U>((U(1) << bits) - 1) : static_cast<U>(~U(0));

        bool fits(U value) const {
            if constexpr (is_narrower) return (value >> bits) == 0;
            return true;
        }

        void report(U value) const {
            if(reported) return;
            reported = true;
            reporter::instance().error(format("[%s] the value %s does not fit the port, it is %u bits wide",
                                              port_name.c_str(), hex(value, 2 * sizeof(U)).c_str(), bits));
        }

        std::string port_name;
        mutable T cache{};
        mutable bool reported = false;
    };

    /// The view of every port that is not one bit, the edges are not part of the interface of those signals
    template<typename T, typename U>
    class port_view : public port_view_base<T, U> {
    public:
        using port_view_base<T, U>::port_view_base;
    };

    /// The view of a one bit port: the interface of a bool signal asks for the edges as well. Nothing that is
    /// connected to a port of the model waits for an edge of it, the model is sensitive to the value, so the events
    /// handed out are never notified
    template<typename U>
    class port_view<bool, U> : public port_view_base<bool, U> {
    public:
        using port_view_base<bool, U>::port_view_base;

        const sc_event &posedge_event() const override {return never;}
        const sc_event &negedge_event() const override {return never;}
        bool posedge() const override {return this->signal.event() && this->read();}
        bool negedge() const override {return this->signal.event() && !this->read();}

    private:
        sc_event never;
    };

}

#endif //SCTB_PORT_VIEW_HPP
