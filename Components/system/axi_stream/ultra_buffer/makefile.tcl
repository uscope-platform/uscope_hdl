# Copyright 2021 University of Nottingham Ningbo China
# Author: Filippo Savi <filssavi@gmail.com>
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set project_name "ultra_buffer"
set origin_dir "."

set base_dir /home/filssavi/git/uplatform-hdl/
set commons_dir  [list  /home/filssavi/git/uplatform-hdl//Components/Common ]

set synth_sources [list ${base_dir}/public/Components/system/axi_stream/ultra_buffer/rtl/ultra_buffer.sv ]

set sim_sources [list ${base_dir}/public/Components/Common/interfaces.svh ${base_dir}/public/Components/system/axi_stream/ultra_buffer/tb/ultra_buffer_tb.sv ]

set constraints_sources [list ]

set board_part ""

# Create project
create_project ${project_name} ./${project_name} -part xc7z020clg400-1

if {$board_part ne ""} {
    set_property board_part $board_part [current_project]
}

# Set the directory path for the new project
set proj_dir [get_property directory [current_project]]

set obj [current_project]


source /home/filssavi/git/uplatform-hdl/public/set_properties.tcl


add_files -norecurse $synth_sources

set_property top ultra_buffer [get_filesets sources_1]

set_property include_dirs {$commons_dir} [get_filesets sources_1]

set_property SOURCE_SET sources_1 [get_filesets sim_1]
add_files -fileset sim_1 -norecurse $sim_sources

set_property top ultra_buffer_tb [get_filesets sim_1]




update_compile_order