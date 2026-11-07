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

// Helpers for the testbenches of the floating point IPs: the bits of a float, the cases that random words almost never
// reach, and the classification of the result of an operation on two operands

#ifndef FCORE_FP32_HPP
#define FCORE_FP32_HPP

#include <cstdint>
#include <cstring>
#include <random>
#include <string>
#include <vector>

namespace fp32 {

    constexpr uint32_t sign_mask = 0x80000000;
    constexpr uint32_t exponent_mask = 0x7F800000;
    constexpr uint32_t mantissa_mask = 0x007FFFFF;

    inline bool is_nan(uint32_t bits) {return (bits & exponent_mask) == exponent_mask && (bits & mantissa_mask) != 0;}
    inline bool is_infinite(uint32_t bits) {return (bits & ~sign_mask) == exponent_mask;}

    inline float to_float(uint32_t bits) {
        float value;
        std::memcpy(&value, &bits, sizeof(value));
        return value;
    }

    inline uint32_t to_bits(float value) {
        uint32_t bits;
        std::memcpy(&bits, &value, sizeof(bits));
        return bits;
    }

    /// A denormal becomes a zero with the same sign
    inline uint32_t flush_denormal(uint32_t bits) {return (bits & exponent_mask) == 0 ? bits & sign_mask : bits;}

    /// A NaN only has to stay a NaN, its payload is not checked
    inline bool matches(uint32_t got, uint32_t expected) {
        if(is_nan(expected)) return is_nan(got);
        return got == expected;
    }

    /// A random float. Random words are almost never zero, denormal, infinite or NaN, and operations on them almost never
    /// overflow or underflow, so those cases are generated on purpose
    inline uint32_t generate(std::mt19937_64 &rng) {
        const uint32_t value = rng();
        switch(rng() % 8){
            case 0:
                // zero or denormal
                return value & ~exponent_mask;
            case 1:
                // infinity or NaN
                return (rng() % 2) ? (value | exponent_mask) & ~mantissa_mask : value | exponent_mask;
            case 2:
                // the bottom of the normal range, where results are denormal
                return (value & ~exponent_mask) | ((rng() % 3) << 23);
            case 3:
                // the top of the range, where results overflow
                return (value & ~exponent_mask) | ((0xFD + rng() % 2) << 23);
            default:
                return value;
        }
    }

    inline std::vector<std::string> binary_class_names() {
        return {"zero", "flushed denormal", "normal", "overflow", "infinity operand", "nan"};
    }

    /// The kind of result an operation on two operands gave, from the bits of the result before a denormal is flushed
    inline size_t binary_class(uint32_t raw, uint32_t a, uint32_t b) {
        const uint32_t exponent = raw & exponent_mask;
        if(is_nan(raw)) return 5;
        if(exponent == exponent_mask) return (is_infinite(a) || is_infinite(b)) ? 4 : 3;
        if(exponent == 0) return (raw & mantissa_mask) == 0 ? 0 : 1;
        return 2;
    }

}

#endif //FCORE_FP32_HPP
