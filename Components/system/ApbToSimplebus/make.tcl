set project_name "APB_to_simplebus"
set origin_dir "."


set synth_sources [glob ./rtl/*]
set included_sources "../Common/interfaces.sv"
set sim_sources [glob ./tb/*]

# Create project
create_project ${project_name} ./${project_name} -part xc7z020clg400-1

# Set the directory path for the new project
set proj_dir [get_property directory [current_project]]

set obj [current_project]

source "../../set_properties.tcl"

source AXI_VIP.tcl

add_files -norecurse $synth_sources
add_files -norecurse $included_sources
set_property SOURCE_SET sources_1 [get_filesets sim_1]
add_files -fileset sim_1 -norecurse $sim_sources
add_files -fileset sim_1 -norecurse $included_sources
set_property include_dirs "../Common/" [get_filesets sources_1]
update_compile_order