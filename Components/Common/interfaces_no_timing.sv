// Copyright 2026 Filippo Savi
// Author: Filippo Savi <filssavi@gmail.com>
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// The axi_stream interface from interfaces.sv without the testbench tasks, which use wait statements
// and delays. Verilator needs --timing for those, which for SystemC testbenches needs a SystemC library
// built with C++20. The signals, parameters and modports are the same, so it can replace interfaces.sv
// wherever the tasks are not used.
interface axi_stream #(DATA_WIDTH = 32, USER_WIDTH = 32, DEST_WIDTH = 32, CLOCK_PERIOD = 10);
    logic [DATA_WIDTH-1:0] data;
    logic [USER_WIDTH-1:0] user;
    logic [DEST_WIDTH-1:0] dest;
    logic valid;
    logic ready;
    logic tlast;

    modport master(input  ready, output data, valid, tlast, user, dest);
    modport slave (output  ready, input data, valid, tlast, user, dest);
    modport watcher(input data, valid, tlast, user, dest,ready);
endinterface
