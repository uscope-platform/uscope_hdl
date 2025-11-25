set project_name fCore2
set origin_dir "."
set base_dir /home/fils/git/uscope_hdl/
set commons_dir [list "/home/fils/git/uscope_hdl/Components/Common" ]
set synth_sources [list "${base_dir}/public/Components/Common/DP_RAM.sv" "${base_dir}/public/Components/Common/interfaces.sv" "${base_dir}/public/Components/system/axi_lite/external_registers_cu/rtl/axil_external_registers_cu.sv" "${base_dir}/public/Components/system/axi_lite/skid_buffer/rtl/axil_skid_buffer.sv" "${base_dir}/public/Components/system/axi_stream/fifo/rtl/axis_fifo_xpm.sv" "${base_dir}/public/Components/system/axi_stream/register_slice/rtl/register_slice.sv" "${base_dir}/public/Components/system/fcore/alu/rtl/FP_saturator.sv" "${base_dir}/public/Components/system/fcore/alu/rtl/div_alu_wrapper.sv" "${base_dir}/public/Components/system/fcore/alu/rtl/simple_alu_wrapper.sv" "${base_dir}/public/Components/system/fcore/istore/rtl/fCore_Istore.sv" "${base_dir}/public/Components/system/fcore/istore/rtl/istore_axi_interface.sv" "${base_dir}/public/Components/system/fcore/istore/rtl/istore_memory.sv" "${base_dir}/public/Components/system/fcore/rtl/fCore.sv" "${base_dir}/public/Components/system/fcore/rtl/fCore_ControlUnit.sv" "${base_dir}/public/Components/system/fcore/rtl/fCore_FP_ALU.sv" "${base_dir}/public/Components/system/fcore/rtl/fCore_ISA.sv" "${base_dir}/public/Components/system/fcore/rtl/fCore_bitmanip_unit.sv" "${base_dir}/public/Components/system/fcore/rtl/fCore_compare_unit.sv" "${base_dir}/public/Components/system/fcore/rtl/fCore_decoder.sv" "${base_dir}/public/Components/system/fcore/rtl/fCore_dma_endpoint.sv" "${base_dir}/public/Components/system/fcore/rtl/fCore_efi_memory_handler.sv" "${base_dir}/public/Components/system/fcore/rtl/fCore_logic_unit.sv" "${base_dir}/public/Components/system/fcore/rtl/fCore_pipeline_tracker.sv" "${base_dir}/public/Components/system/fcore/rtl/fCore_registerFile.sv" "${base_dir}/public/Components/system/fcore/rtl/fCore_tracer.sv" "${base_dir}/public/Components/system/fcore/rtl/fcore_common_io.sv" ]
set sim_sources [list "${base_dir}/public/Components/system/axi_full/crossbar/rtl/axi_address_decoder.sv" "${base_dir}/public/Components/system/axi_full/crossbar/rtl/axi_skid_buffer_r_data.sv" "${base_dir}/public/Components/system/axi_full/crossbar/rtl/axi_skid_buffer_w_addr.sv" "${base_dir}/public/Components/system/axi_full/crossbar/rtl/axi_skid_buffer_w_data.sv" "${base_dir}/public/Components/system/axi_full/crossbar/rtl/axi_skid_buffer_w_resp.sv" "${base_dir}/public/Components/system/axi_full/crossbar/rtl/axi_xbar.sv" "${base_dir}/public/Components/system/axi_lite/axis_to_axil/rtl/axis_to_axil.sv" "${base_dir}/public/Components/system/axi_stream/data_mover/rtl/axis_data_mover.sv" "${base_dir}/public/Components/system/axi_stream/skid_buffer/rtl/axis_skid_buffer.sv" "${base_dir}/public/Components/system/fcore/tb/fCore_tb.sv" "${base_dir}/public/Components/system/fcore/tb/micro_bench/csel/csel.mem" "${base_dir}/public/Components/system/fcore/tb/micro_bench/csel/fCore_conditional_select_tb.sv" ]
set constraints_sources [list ]
# Create project
create_project ${project_name} ./${project_name}
set_property part xc7z020clg400-1 [current_project]
# Set the directory path for the new project
set proj_dir [get_property directory [current_project]]
set obj [current_project]
source /home/fils/git/uscope_hdl/public/set_properties.tcl
source /home/fils/git/uscope_hdl/public/Components/system/fcore/alu/ip/adder.tcl
adder fast_adder 5
adder slow_adder 8
source /home/fils/git/uscope_hdl/public/Components/system/fcore/alu/ip/fti.tcl
fti fti 5
source /home/fils/git/uscope_hdl/public/Components/system/fcore/alu/ip/itf.tcl
itf itf 5
source /home/fils/git/uscope_hdl/public/Components/system/fcore/alu/ip/multiplier.tcl
multiplier mul 5
source /home/fils/git/uscope_hdl/public/Components/system/fcore/alu/ip/reciprocal.tcl
reciprocal rec 5
add_files -norecurse $synth_sources
set_property top fCore [get_filesets sources_1]
set_property include_dirs $commons_dir [get_filesets sources_1]
set_property SOURCE_SET sources_1 [get_filesets sim_1]
add_files -fileset sim_1 -norecurse $sim_sources
set_property top fCore_tb [get_filesets sim_1]
update_compile_order
