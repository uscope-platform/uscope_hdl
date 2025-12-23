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
`ifndef __HELPERS_SV__
`define __HELPERS_SV__
function [15:0] get_axis_metadata (input [4:0] size,input is_signed, input is_float);
reg [3:0] biased_size;
begin
    biased_size = size -8;
    get_axis_metadata = { 10'h0, is_float, is_signed, biased_size};
end
endfunction

function  is_axis_float (input [15:0] data);
begin
    is_axis_float = data[5];
end
endfunction

`endif 