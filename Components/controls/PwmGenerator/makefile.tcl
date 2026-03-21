set project_name PwmGenerator
set origin_dir "."
set base_dir /home/vivado/hdl
set commons_dir [list "/home/vivado/hdl/public/Components/Common" ]
set synth_sources [list "${base_dir}/public/Components/Common/interfaces.sv" "${base_dir}/public/Components/controls/PwmGenerator/rtl/ChainControlUnit.sv" "${base_dir}/public/Components/controls/PwmGenerator/rtl/CompareUnit.sv" "${base_dir}/public/Components/controls/PwmGenerator/rtl/Counter.sv" "${base_dir}/public/Components/controls/PwmGenerator/rtl/CounterCore.sv" "${base_dir}/public/Components/controls/PwmGenerator/rtl/CounterEnableDelayCore.sv" "${base_dir}/public/Components/controls/PwmGenerator/rtl/DeadTimeGenerator.sv" "${base_dir}/public/Components/controls/PwmGenerator/rtl/PinControl.sv" "${base_dir}/public/Components/controls/PwmGenerator/rtl/PwmControlUnit.sv" "${base_dir}/public/Components/controls/PwmGenerator/rtl/PwmGenerator.sv" "${base_dir}/public/Components/controls/PwmGenerator/rtl/ResolutionEnhancer.sv" "${base_dir}/public/Components/controls/PwmGenerator/rtl/SyncEngine.sv" "${base_dir}/public/Components/controls/PwmGenerator/rtl/TimebaseGenerator.sv" "${base_dir}/public/Components/controls/PwmGenerator/rtl/pwmChain.sv" "${base_dir}/public/Components/system/axi_lite/external_registers_cu/rtl/axil_external_registers_cu.sv" "${base_dir}/public/Components/system/axi_lite/skid_buffer/rtl/axil_skid_buffer.sv" ]
set sim_sources [list "${base_dir}/public/Components/controls/PwmGenerator/tb/pwm_generator_multi_chain_tb.sv" ]
set constraints_sources [list "/home/vivado/hdl/public/Components/controls/PwmGenerator/PwmGenerator.xdc" ]
# Create project
create_project ${project_name} ./${project_name}
set_property part xc7z020clg400-1 [current_project]
# Set the directory path for the new project
set proj_dir [get_property directory [current_project]]
set obj [current_project]
source /home/vivado/hdl/public/set_properties.tcl
add_files -norecurse $synth_sources
set_property top PwmGenerator [get_filesets sources_1]
set_property include_dirs $commons_dir [get_filesets sources_1]
set_property SOURCE_SET sources_1 [get_filesets sim_1]
add_files -fileset constrs_1 -norecurse  $constraints_sources
add_files -fileset sim_1 -norecurse $sim_sources
set_property top pwm_generator_multi_chain_tb [get_filesets sim_1]
update_compile_order
