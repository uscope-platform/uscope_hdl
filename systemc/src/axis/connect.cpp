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

#include "sctb/axis/connect.hpp"

#include <memory>
#include <string>
#include <type_traits>
#include <typeinfo>

#include "sctb/report.hpp"
#include "port_view.hpp"

namespace sctb {

    namespace {

        // Binds the port to the signal if it is an input or an output of type T, and tells whether it was. A port of
        // the type of the signal is bound to it, a narrower one to a view of it that the bus keeps alive
        template<typename T, typename U>
        bool try_bind(axis_bus &bus, sc_object *port, const std::string &name, sc_signal<U> &signal) {
            auto input = dynamic_cast<sc_in<T> *>(port);
            auto output = dynamic_cast<sc_out<T> *>(port);
            if(input == nullptr && output == nullptr) return false;

            if constexpr (std::is_same<T, U>::value) {
                if(input) (*input)(signal); else (*output)(signal);
            } else {
                auto view = std::make_shared<port_view<T, U>>(signal, name);
                bus.adopt(view);
                if(input) (*input)(*view); else (*output)(*view);
            }
            return true;
        }

        // Binds the port of the model called port_name to the signal. The port can be an input or an output of any of
        // the types Ts, which are the ones Verilator gives to a port that can hold the signal
        template<typename... Ts, typename U>
        void bind_port(axis_bus &bus, const sc_module &model, const std::string &port_name, sc_signal<U> &signal) {
            const std::string name = std::string(model.name()) + "." + port_name;
            sc_object *port = sc_find_object(name.c_str());
            if(port == nullptr) {
                SC_REPORT_FATAL("sctb", format("the model has no port called %s", name.c_str()).c_str());
            }
            if((try_bind<Ts>(bus, port, name, signal) || ...)) return;
            SC_REPORT_FATAL("sctb", format("the port %s is of the type %s, which a port of this signal can not have (a port wider "
                                           "than 64 bits is a sc_bv, which is not supported)", name.c_str(), typeid(*port).name()).c_str());
        }

    }

    void connect_stream(axis_bus &bus, const sc_module &model, const std::string &stream) {
        // the control signals are one bit
        bind_port<bool>(bus, model, stream + "_valid", bus.valid);
        bind_port<bool>(bus, model, stream + "_ready", bus.ready);
        bind_port<bool>(bus, model, stream + "_tlast", bus.tlast);
        // the others are as wide as the stream, from 1 to 64 bits for the data and 32 for dest and user
        bind_port<uint64_t, uint32_t, uint16_t, uint8_t, bool>(bus, model, stream + "_data", bus.data);
        bind_port<uint32_t, uint16_t, uint8_t, bool>(bus, model, stream + "_dest", bus.dest);
        bind_port<uint32_t, uint16_t, uint8_t, bool>(bus, model, stream + "_user", bus.user);
    }

}
