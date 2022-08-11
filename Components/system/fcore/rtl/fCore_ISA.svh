// Copyright 2021 University of Nottingham Ningbo China
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

package fcore_isa;
    parameter NOP = 0;
    parameter ADD = 1;
    parameter SUB = 2;
    parameter MUL = 3; 
    parameter ITF = 4;
    parameter FTI = 5;
    parameter LDC = 6;
    parameter LDR = 7;
    parameter BGT = 8;
    parameter BLE = 9;
    parameter BEQ = 10;
    parameter BNE = 11;
    parameter STOP = 12;
    parameter LAND = 13;
    parameter LOR = 14;
    parameter LNOT = 15;
    parameter SATP = 16;
    parameter SATN = 17;
    parameter REC = 18;
    parameter POPCNT = 19;
endpackage