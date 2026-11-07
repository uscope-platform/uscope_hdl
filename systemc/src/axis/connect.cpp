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

#include "sctb/report.hpp"

namespace sctb {

    // Binds the port of the model called port_name to the signal, whether it is an input or an output
    template<typename T>
    static void bind_port(const sc_module &model, const std::string &port_name, sc_signal<T> &signal) {
        const std::string name = std::string(model.name()) + "." + port_name;
        sc_object *port = sc_find_object(name.c_str());
        if(port == nullptr) {
            SC_REPORT_FATAL("sctb", format("the model has no port called %s", name.c_str()).c_str());
        }
        if(auto input = dynamic_cast<sc_in<T> *>(port)) {
            (*input)(signal);
        } else if(auto output = dynamic_cast<sc_out<T> *>(port)) {
            (*output)(signal);
        } else {
            SC_REPORT_FATAL("sctb", format("the port %s is not the type of the signal it is connected to, "
                                           "the data of a stream is 64 bits wide", name.c_str()).c_str());
        }
    }

    void connect_stream(axis_bus &bus, const sc_module &model, const std::string &stream) {
        bind_port(model, stream + "_valid", bus.valid);
        bind_port(model, stream + "_ready", bus.ready);
        bind_port(model, stream + "_data", bus.data);
        bind_port(model, stream + "_dest", bus.dest);
        bind_port(model, stream + "_user", bus.user);
        bind_port(model, stream + "_tlast", bus.tlast);
    }

}
