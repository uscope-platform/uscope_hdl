export DISPLAY=":0" #VSCODE TERMINAL DOES NOT DEFINE THE $DISPLAY VARIABLE THUS VIVADO CANNOT LAUNCH THE GUI, THIS FIXES THAT
# Check if arguments have been supplied
if [ -z "$1" ]
  then
    echo "Test assenbly file path needed"
    exit 1
fi
rm -r  build &> /dev/null

#SETUP BUILD DIRECTORY AND VARIABLES
mkdir -p build
cd build

TEST_FILE_NAME="test_program.mem"
BASE_DIR="../../../../.."
SOCK_DIR="$BASE_DIR/sock"
COMPONENTS_DIR="$BASE_DIR/Components"
SCRIPT_DIR="$BASE_DIR/script"
VLOG_SIM_SOURCES="../ip/*.*v ../ip/*.vh $COMPONENTS_DIR/system/fcore/rtl/* ../vip_bd_wrapper.sv ../../istore/rtl/fCore_Istore.sv"
VHDL_SIM_SOURCES="../ip/*.vhd"
LIB_INCLUDES="-L xbip_utils_v3_0_10 -L axi_utils_v2_0_6 -L xbip_pipe_v3_0_6 -L xbip_dsp48_wrapper_v3_0_4 -L xbip_dsp48_addsub_v3_0_6 -L xbip_dsp48_multadd_v3_0_6 -L xbip_bram18k_v3_0_6 -L mult_gen_v12_0_16 -L floating_point_v7_1_10 -L xil_defaultlib -L axis_infrastructure_v1_1_0 -L axis_register_slice_v1_1_21 -L axis_switch_v1_1_21 -L axis_subset_converter_v1_1_21 -L axi_infrastructure_v1_1_0 -L axi_vip_v1_1_7 -L xilinx_vip -L unisims_ver -L unimacro_ver -L secureip -L xpm"
# "COMPILE" SYSTEM VERILOG FILES

../fCore_has $(readlink -f ../$1)  --mem --o $TEST_FILE_NAME


{
# Check if Vivado is in PATH inclusion script
# This needs to be done after fCore_has is done since vivado fucks with the library paths putting its old crap before system ones
if ! type "vivado" > /dev/null; then
  source /fast_software/Vivado/2020.1/settings64.sh
fi
} &> /dev/null

{
  xvlog -i "$COMPONENTS_DIR/Common/"  $LIB_INCLUDES  -sv $VLOG_SIM_SOURCES "../fCore_tb.sv" --log vlog.log
  xvhdl $VHDL_SIM_SOURCES --log vhdl.log
  xelab -d "PROGRAM_PATH=$PWD/$TEST_FILE_NAME" -i "$COMPONENTS_DIR/Common/"  $LIB_INCLUDES --debug all -svlog "../fCore_tb.sv" -s TestSnapshot --log elab.log
  #xsim TestSnapshot --runall --log sim.log
  xsim TestSnapshot --gui
} &> /dev/null

./../fcore_emulator.py "$TEST_FILE_NAME" --c test_result.txt

#CLEAN UP AFTERWARDS
cd ../
#rm -r  build
