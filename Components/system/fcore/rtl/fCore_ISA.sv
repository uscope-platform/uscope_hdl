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
    parameter NOP = 0;    // 0x0
    parameter ADD = 1;    // 0x1
    parameter SUB = 2;    // 0x2
    parameter MUL = 3;    // 0x3
    parameter ITF = 4;    // 0x4
    parameter FTI = 5;    // 0x5
    parameter LDC = 6;    // 0x6
    parameter LDR = 7;    // 0x7
    parameter BGT = 8;    // 0x8
    parameter BLE = 9;    // 0x9
    parameter BEQ = 10;   // 0xa
    parameter BNE = 11;   // 0xb
    parameter STOP = 12;  // 0xc
    parameter LAND = 13;  // 0xd
    parameter LOR = 14;   // 0xe
    parameter LNOT = 15;  // 0xf
    parameter SATP = 16;  // 0x10
    parameter SATN = 17;  // 0x11
    parameter REC = 18;   // 0x12
    parameter POPCNT = 19;// 0x13
    parameter ABS = 20;   // 0x14
    parameter EFI = 21;   // 0x15
    parameter BSET = 22;  // 0x16
    parameter BSEL = 25;  // 0x19
    parameter LXOR = 26;  // 0x1a
    parameter CSEL = 27;  // 0x1b
endpackage
