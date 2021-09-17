set project_name "AD2S1210"
set origin_dir "."

set base_dir /home/fils/git/sicdrive-hdl
set commons_dir  /home/fils/git/sicdrive-hdl/Components/Common/



set synth_sources [list /home/fils/git/sicdrive-hdl/Components/Common/zynqApb_wrapper.sv /home/fils/git/sicdrive-hdl/Components/ApbToSimplebus/rtl/APB_to_Simplebus.sv /home/fils/git/sicdrive-hdl/Components/SimplebusInterconnect/rtl/SimplebusInterconnect_M1_S3.v /home/fils/git/sicdrive-hdl/Components/ExternalDrivers/AD2S1210/rtl/AD2S1210.sv /home/fils/git/sicdrive-hdl/Components/EnableGenerator/rtl/EnableGenerator.v /home/fils/git/sicdrive-hdl/Components/ExternalDrivers/AD2S1210/rtl/ad2s1210_CU.sv /home/fils/git/sicdrive-hdl/Components/SPI/rtl/Spi.sv /home/fils/git/sicdrive-hdl/Components/EnableGenerator/rtl/enable_generator_counter.v /home/fils/git/sicdrive-hdl/Components/EnableGenerator/rtl/enable_comparator.v /home/fils/git/sicdrive-hdl/Components/Common/RegisterFile.v /home/fils/git/sicdrive-hdl/Components/EnableGenerator/rtl/enable_generator_core.v /home/fils/git/sicdrive-hdl/Components/SPI/rtl/ClockGen.sv /home/fils/git/sicdrive-hdl/Components/SPI/rtl/SpiRegister.sv /home/fils/git/sicdrive-hdl/Components/SPI/rtl/TransferEngine.sv /home/fils/git/sicdrive-hdl/Components/SPI/rtl/SpiControlUnit.sv /home/fils/git/sicdrive-hdl/Components/ExternalDrivers/AD2S1210/rtl/ad2s1210_tl.sv ]

set sim_sources [list /home/fils/git/sicdrive-hdl/Components/ExternalDrivers/AD2S1210/tb/ad2s1210_tl_test.sv /home/fils/git/sicdrive-hdl/Components/ExternalDrivers/AD2S1210/tb/AD2S1210_tb.sv ]

set constraints_sources [list ]

# Create project
create_project ${project_name} ./${project_name} -part xc7z020clg400-1

# Set the directory path for the new project
set proj_dir [get_property directory [current_project]]

set obj [current_project]

source /home/fils/git/sicdrive-hdl/set_properties.tcl
source /home/fils/git/sicdrive-hdl/Components/Common/zynqApbBd.tcl

add_files -norecurse $synth_sources
    set_property top ad2s1210_tl [get_filesets sources_1]
set_property include_dirs $commons_dir [get_filesets sources_1]

set_property SOURCE_SET sources_1 [get_filesets sim_1]
add_files -fileset sim_1 -norecurse $sim_sources
    set_property top AD2S1210_tb [get_filesets sim_1]

update_compile_order