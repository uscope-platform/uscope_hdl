// Copyright 2024 Filippo Savi
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

module float_to_fixed_wrapper(
    input wire clock,
    axi_stream.slave data_in,
    axi_stream.master data_out
);


  wire clk;
  wire [31:0]data_in_tdata;
  wire data_in_tvalid;
  wire [31:0]data_out_tdata;
  wire data_out_tvalid;

  float_to_fixed float_to_fixed_i (
    .clock(clock),
    .data_in_tdata(data_in.data),
    .data_in_tvalid(data_in.valid),
    .data_out_tdata(data_out.data),
    .data_out_tvalid(data_out.valid)
);
endmodule
