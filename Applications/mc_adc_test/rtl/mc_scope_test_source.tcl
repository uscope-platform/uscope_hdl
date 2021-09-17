
################################################################
# This is a generated script based on design: Data_source
#
# Though there are limitations about the generated script,
# the main purpose of this utility is to make learning
# IP Integrator Tcl commands easier.
################################################################

namespace eval _tcl {
proc get_script_folder {} {
   set script_path [file normalize [info script]]
   set script_folder [file dirname $script_path]
   return $script_folder
}
}
variable script_folder
set script_folder [_tcl::get_script_folder]


################################################################
# START
################################################################

# To test this script, run the following commands from Vivado Tcl console:
# source Data_source_script.tcl

# If there is no project opened, this script will create a
# project, but make sure you do not have an existing project
# <./myproj/project_1.xpr> in the current working folder.

set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
   create_project project_1 myproj -part xc7z010clg400-1
   set_property BOARD_PART em.avnet.com:microzed_7010:part0:1.1 [current_project]
}


# CHANGE DESIGN NAME HERE
variable design_name
set design_name Data_source

# If you do not already have an existing IP Integrator design open,
# you can create a design using the following command:
#    create_bd_design $design_name

# Creating design if needed
set errMsg ""
set nRet 0

set cur_design [current_bd_design -quiet]
set list_cells [get_bd_cells -quiet]

if { ${design_name} eq "" } {
   # USE CASES:
   #    1) Design_name not set

   set errMsg "Please set the variable <design_name> to a non-empty value."
   set nRet 1

} elseif { ${cur_design} ne "" && ${list_cells} eq "" } {
   # USE CASES:
   #    2): Current design opened AND is empty AND names same.
   #    3): Current design opened AND is empty AND names diff; design_name NOT in project.
   #    4): Current design opened AND is empty AND names diff; design_name exists in project.

   if { $cur_design ne $design_name } {
      common::send_gid_msg -ssname BD::TCL -id 2001 -severity "INFO" "Changing value of <design_name> from <$design_name> to <$cur_design> since current design is empty."
      set design_name [get_property NAME $cur_design]
   }
   common::send_gid_msg -ssname BD::TCL -id 2002 -severity "INFO" "Constructing design in IPI design <$cur_design>..."

} elseif { ${cur_design} ne "" && $list_cells ne "" && $cur_design eq $design_name } {
   # USE CASES:
   #    5) Current design opened AND has components AND same names.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 1
} elseif { [get_files -quiet ${design_name}.bd] ne "" } {
   # USE CASES: 
   #    6) Current opened design, has components, but diff names, design_name exists in project.
   #    7) No opened design, design_name exists in project.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 2

} else {
   # USE CASES:
   #    8) No opened design, design_name not in project.
   #    9) Current opened design, has components, but diff names, design_name not in project.

   common::send_gid_msg -ssname BD::TCL -id 2003 -severity "INFO" "Currently there is no design <$design_name> in project, so creating one..."

   create_bd_design $design_name

   common::send_gid_msg -ssname BD::TCL -id 2004 -severity "INFO" "Making design <$design_name> as current_bd_design."
   current_bd_design $design_name

}

common::send_gid_msg -ssname BD::TCL -id 2005 -severity "INFO" "Currently the variable <design_name> is equal to \"$design_name\"."

if { $nRet != 0 } {
   catch {common::send_gid_msg -ssname BD::TCL -id 2006 -severity "ERROR" $errMsg}
   return $nRet
}

set bCheckIPsPassed 1
##################################################################
# CHECK IPs
##################################################################
set bCheckIPs 1
if { $bCheckIPs == 1 } {
   set list_check_ips "\ 
xilinx.com:ip:dds_compiler:6.0\
"

   set list_ips_missing ""
   common::send_gid_msg -ssname BD::TCL -id 2011 -severity "INFO" "Checking if the following IPs exist in the project's IP catalog: $list_check_ips ."

   foreach ip_vlnv $list_check_ips {
      set ip_obj [get_ipdefs -all $ip_vlnv]
      if { $ip_obj eq "" } {
         lappend list_ips_missing $ip_vlnv
      }
   }

   if { $list_ips_missing ne "" } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2012 -severity "ERROR" "The following IPs are not found in the IP Catalog:\n  $list_ips_missing\n\nResolution: Please add the repository containing the IP(s) to the project." }
      set bCheckIPsPassed 0
   }

}

if { $bCheckIPsPassed != 1 } {
  common::send_gid_msg -ssname BD::TCL -id 2023 -severity "WARNING" "Will not continue with creation of design due to the error(s) above."
  return 3
}

##################################################################
# DESIGN PROCs
##################################################################



# Procedure to create entire design; Provide argument to make
# procedure reusable. If parentCell is "", will use root.
proc create_root_design { parentCell } {

  variable script_folder
  variable design_name

  if { $parentCell eq "" } {
     set parentCell [get_bd_cells /]
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj


  # Create interface ports
  set channel_1 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 channel_1 ]

  set channel_2 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 channel_2 ]

  set channel_3 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 channel_3 ]

  set channel_4 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 channel_4 ]

  set channel_5 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 channel_5 ]

  set channel_6 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 channel_6 ]


  # Create ports
  set aclk_0 [ create_bd_port -dir I -type clk aclk_0 ]
  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {channel_1:channel_2:channel_3:channel_4:channel_6:channel_5} \
 ] $aclk_0

  # Create instance: dds_compiler_0, and set properties
  set dds_compiler_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:dds_compiler:6.0 dds_compiler_0 ]
  set_property -dict [ list \
   CONFIG.Channels {1} \
   CONFIG.DATA_Has_TLAST {Not_Required} \
   CONFIG.Frequency_Resolution {0.4} \
   CONFIG.Has_Phase_Out {false} \
   CONFIG.Latency {8} \
   CONFIG.M_DATA_Has_TUSER {Not_Required} \
   CONFIG.M_PHASE_Has_TUSER {Not_Required} \
   CONFIG.Noise_Shaping {None} \
   CONFIG.Output_Frequency1 {0} \
   CONFIG.Output_Frequency2 {0} \
   CONFIG.Output_Frequency3 {0} \
   CONFIG.Output_Frequency4 {0} \
   CONFIG.Output_Frequency5 {0} \
   CONFIG.Output_Frequency6 {0} \
   CONFIG.Output_Selection {Cosine} \
   CONFIG.Output_Width {12} \
   CONFIG.PINC1 {1101} \
   CONFIG.PINC2 {0} \
   CONFIG.PINC3 {0} \
   CONFIG.PINC4 {0} \
   CONFIG.PINC5 {0} \
   CONFIG.PINC6 {0} \
   CONFIG.Parameter_Entry {Hardware_Parameters} \
   CONFIG.Phase_Width {16} \
   CONFIG.Phase_offset {Fixed} \
   CONFIG.S_PHASE_Has_TUSER {Not_Required} \
 ] $dds_compiler_0

  # Create instance: dds_compiler_1, and set properties
  set dds_compiler_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:dds_compiler:6.0 dds_compiler_1 ]
  set_property -dict [ list \
   CONFIG.Channels {1} \
   CONFIG.DATA_Has_TLAST {Not_Required} \
   CONFIG.Frequency_Resolution {0.4} \
   CONFIG.Has_Phase_Out {false} \
   CONFIG.Latency {8} \
   CONFIG.M_DATA_Has_TUSER {Not_Required} \
   CONFIG.M_PHASE_Has_TUSER {Not_Required} \
   CONFIG.Noise_Shaping {None} \
   CONFIG.Output_Frequency1 {0} \
   CONFIG.Output_Frequency2 {0} \
   CONFIG.Output_Frequency3 {0} \
   CONFIG.Output_Frequency4 {0} \
   CONFIG.Output_Frequency5 {0} \
   CONFIG.Output_Frequency6 {0} \
   CONFIG.Output_Selection {Cosine} \
   CONFIG.Output_Width {12} \
   CONFIG.PINC1 {1101} \
   CONFIG.PINC2 {0} \
   CONFIG.PINC3 {0} \
   CONFIG.PINC4 {0} \
   CONFIG.PINC5 {0} \
   CONFIG.PINC6 {0} \
   CONFIG.POFF1 {0100010001000100} \
   CONFIG.Parameter_Entry {Hardware_Parameters} \
   CONFIG.Phase_Width {16} \
   CONFIG.Phase_offset {Fixed} \
   CONFIG.S_PHASE_Has_TUSER {Not_Required} \
 ] $dds_compiler_1

  # Create instance: dds_compiler_2, and set properties
  set dds_compiler_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:dds_compiler:6.0 dds_compiler_2 ]
  set_property -dict [ list \
   CONFIG.Channels {1} \
   CONFIG.DATA_Has_TLAST {Not_Required} \
   CONFIG.Frequency_Resolution {0.4} \
   CONFIG.Has_Phase_Out {false} \
   CONFIG.Latency {8} \
   CONFIG.M_DATA_Has_TUSER {Not_Required} \
   CONFIG.M_PHASE_Has_TUSER {Not_Required} \
   CONFIG.Noise_Shaping {None} \
   CONFIG.Output_Frequency1 {0} \
   CONFIG.Output_Frequency2 {0} \
   CONFIG.Output_Frequency3 {0} \
   CONFIG.Output_Frequency4 {0} \
   CONFIG.Output_Frequency5 {0} \
   CONFIG.Output_Frequency6 {0} \
   CONFIG.Output_Selection {Cosine} \
   CONFIG.Output_Width {12} \
   CONFIG.PINC1 {1101} \
   CONFIG.PINC2 {0} \
   CONFIG.PINC3 {0} \
   CONFIG.PINC4 {0} \
   CONFIG.PINC5 {0} \
   CONFIG.PINC6 {0} \
   CONFIG.POFF1 {1101010101010010} \
   CONFIG.Parameter_Entry {Hardware_Parameters} \
   CONFIG.Phase_Width {16} \
   CONFIG.Phase_offset {Fixed} \
   CONFIG.S_PHASE_Has_TUSER {Not_Required} \
 ] $dds_compiler_2

  # Create instance: dds_compiler_3, and set properties
  set dds_compiler_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:dds_compiler:6.0 dds_compiler_3 ]
  set_property -dict [ list \
   CONFIG.Channels {1} \
   CONFIG.DATA_Has_TLAST {Not_Required} \
   CONFIG.Frequency_Resolution {0.4} \
   CONFIG.Has_Phase_Out {false} \
   CONFIG.Latency {8} \
   CONFIG.M_DATA_Has_TUSER {Not_Required} \
   CONFIG.M_PHASE_Has_TUSER {Not_Required} \
   CONFIG.Noise_Shaping {None} \
   CONFIG.Output_Frequency1 {0} \
   CONFIG.Output_Frequency2 {0} \
   CONFIG.Output_Frequency3 {0} \
   CONFIG.Output_Frequency4 {0} \
   CONFIG.Output_Frequency5 {0} \
   CONFIG.Output_Frequency6 {0} \
   CONFIG.Output_Selection {Cosine} \
   CONFIG.Output_Width {12} \
   CONFIG.PINC1 {1101} \
   CONFIG.PINC2 {0} \
   CONFIG.PINC3 {0} \
   CONFIG.PINC4 {0} \
   CONFIG.PINC5 {0} \
   CONFIG.PINC6 {0} \
   CONFIG.POFF1 {1010101010101000} \
   CONFIG.Parameter_Entry {Hardware_Parameters} \
   CONFIG.Phase_Width {16} \
   CONFIG.Phase_offset {Fixed} \
   CONFIG.S_PHASE_Has_TUSER {Not_Required} \
 ] $dds_compiler_3

  # Create instance: dds_compiler_4, and set properties
  set dds_compiler_4 [ create_bd_cell -type ip -vlnv xilinx.com:ip:dds_compiler:6.0 dds_compiler_4 ]
  set_property -dict [ list \
   CONFIG.Channels {1} \
   CONFIG.DATA_Has_TLAST {Not_Required} \
   CONFIG.Frequency_Resolution {0.4} \
   CONFIG.Has_Phase_Out {false} \
   CONFIG.Latency {8} \
   CONFIG.M_DATA_Has_TUSER {Not_Required} \
   CONFIG.M_PHASE_Has_TUSER {Not_Required} \
   CONFIG.Noise_Shaping {None} \
   CONFIG.Output_Frequency1 {0} \
   CONFIG.Output_Frequency2 {0} \
   CONFIG.Output_Frequency3 {0} \
   CONFIG.Output_Frequency4 {0} \
   CONFIG.Output_Frequency5 {0} \
   CONFIG.Output_Frequency6 {0} \
   CONFIG.Output_Selection {Cosine} \
   CONFIG.Output_Width {12} \
   CONFIG.PINC1 {1101} \
   CONFIG.PINC2 {0} \
   CONFIG.PINC3 {0} \
   CONFIG.PINC4 {0} \
   CONFIG.PINC5 {0} \
   CONFIG.PINC6 {0} \
   CONFIG.POFF1 {101010101010100} \
   CONFIG.Parameter_Entry {Hardware_Parameters} \
   CONFIG.Phase_Width {16} \
   CONFIG.Phase_offset {Fixed} \
   CONFIG.S_PHASE_Has_TUSER {Not_Required} \
 ] $dds_compiler_4

  # Create instance: dds_compiler_5, and set properties
  set dds_compiler_5 [ create_bd_cell -type ip -vlnv xilinx.com:ip:dds_compiler:6.0 dds_compiler_5 ]
  set_property -dict [ list \
   CONFIG.Channels {1} \
   CONFIG.DATA_Has_TLAST {Not_Required} \
   CONFIG.Frequency_Resolution {0.4} \
   CONFIG.Has_Phase_Out {false} \
   CONFIG.Latency {8} \
   CONFIG.M_DATA_Has_TUSER {Not_Required} \
   CONFIG.M_PHASE_Has_TUSER {Not_Required} \
   CONFIG.Noise_Shaping {None} \
   CONFIG.Output_Frequency1 {0} \
   CONFIG.Output_Frequency2 {0} \
   CONFIG.Output_Frequency3 {0} \
   CONFIG.Output_Frequency4 {0} \
   CONFIG.Output_Frequency5 {0} \
   CONFIG.Output_Frequency6 {0} \
   CONFIG.Output_Selection {Cosine} \
   CONFIG.Output_Width {12} \
   CONFIG.PINC1 {1101} \
   CONFIG.PINC2 {0} \
   CONFIG.PINC3 {0} \
   CONFIG.PINC4 {0} \
   CONFIG.PINC5 {0} \
   CONFIG.PINC6 {0} \
   CONFIG.POFF1 {111111111111110} \
   CONFIG.Parameter_Entry {Hardware_Parameters} \
   CONFIG.Phase_Width {16} \
   CONFIG.Phase_offset {Fixed} \
   CONFIG.S_PHASE_Has_TUSER {Not_Required} \
 ] $dds_compiler_5

  # Create interface connections
  connect_bd_intf_net -intf_net dds_compiler_0_M_AXIS_DATA [get_bd_intf_ports channel_1] [get_bd_intf_pins dds_compiler_0/M_AXIS_DATA]
  connect_bd_intf_net -intf_net dds_compiler_1_M_AXIS_DATA [get_bd_intf_ports channel_2] [get_bd_intf_pins dds_compiler_1/M_AXIS_DATA]
  connect_bd_intf_net -intf_net dds_compiler_2_M_AXIS_DATA [get_bd_intf_ports channel_6] [get_bd_intf_pins dds_compiler_2/M_AXIS_DATA]
  connect_bd_intf_net -intf_net dds_compiler_3_M_AXIS_DATA [get_bd_intf_ports channel_5] [get_bd_intf_pins dds_compiler_3/M_AXIS_DATA]
  connect_bd_intf_net -intf_net dds_compiler_4_M_AXIS_DATA [get_bd_intf_ports channel_3] [get_bd_intf_pins dds_compiler_4/M_AXIS_DATA]
  connect_bd_intf_net -intf_net dds_compiler_5_M_AXIS_DATA [get_bd_intf_ports channel_4] [get_bd_intf_pins dds_compiler_5/M_AXIS_DATA]

  # Create port connections
  connect_bd_net -net aclk_0_1 [get_bd_ports aclk_0] [get_bd_pins dds_compiler_0/aclk] [get_bd_pins dds_compiler_1/aclk] [get_bd_pins dds_compiler_2/aclk] [get_bd_pins dds_compiler_3/aclk] [get_bd_pins dds_compiler_4/aclk] [get_bd_pins dds_compiler_5/aclk]

  # Create address segments


  # Restore current instance
  current_bd_instance $oldCurInst

  validate_bd_design
  save_bd_design
}
# End of create_root_design()


##################################################################
# MAIN FLOW
##################################################################

create_root_design ""


