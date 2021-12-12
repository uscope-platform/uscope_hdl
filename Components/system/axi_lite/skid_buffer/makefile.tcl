set project_name "skid_buffer"
set origin_dir "."

set base_dir /home/fils/git/uscope_hdl
set commons_dir  [list  /home/fils/git/uscope_hdl/Components/Common ]



set synth_sources [list $base_dir/public/Components/system/axi_lite/skid_buffer/rtl/axil_skid_buffer.sv ]

set sim_sources [list $base_dir/public/Components/system/axi_lite/skid_buffer/tb/axil_skid_buffer_tb.sv $base_dir/public/Components/system/axi_lite/skid_buffer/tb/test_skid_buffer.sv ]

set constraints_sources [list ]

# Create project
create_project ${project_name} ./${project_name} -part xc7z020clg400-1

# Set the directory path for the new project
set proj_dir [get_property directory [current_project]]

set obj [current_project]


source /home/fils/git/uscope_hdl/public/set_properties.tcl


add_files -norecurse $synth_sources

set_property top axil_skid_buffer [get_filesets sources_1]

set_property include_dirs {$commons_dir} [get_filesets sources_1]

set_property SOURCE_SET sources_1 [get_filesets sim_1]
add_files -fileset sim_1 -norecurse $sim_sources

set_property top axil_skid_buffer_tb [get_filesets sim_1]




update_compile_order