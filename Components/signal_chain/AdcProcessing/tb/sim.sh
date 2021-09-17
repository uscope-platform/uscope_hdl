#!/bin/bash

# Check if arguments have been supplied
if [ -z "$1" ]
  then
    echo "No argument supplied"
    exit 1
fi

# Check if Vivado is in PATH inclusion script
if ! type "vivado" > /dev/null; then
  source /software/Xilinx/Vivado/2018.2/settings64.sh
fi

#SETUP BUILD DIRECTORY AND VARIABLES
mkdir -p build
cd build

BASE_DIR="../../../../.."
SOCK_DIR="$BASE_DIR/sock"
COMPONENTS_DIR="$BASE_DIR/Components"
SCRIPT_DIR="$BASE_DIR/script"
SIM_SOURCES="$COMPONENTS_DIR/AdcProcessing/rtl/* $COMPONENTS_DIR/Common/RegisterFile.v $COMPONENTS_DIR/Common/saturating_adder.v"
TEST_SCRIPT="$COMPONENTS_DIR/AdcProcessing/tb/FIR_test.py"


# "COMPILE" SYSTEM VERILOG FILES
xvlog -i "$COMPONENTS_DIR/Common/" -sv "$SOCK_DIR/sock.sv" $SIM_SOURCES ../$1

xsc $SOCK_DIR/sock.c
#SETUP SIMULATION
xelab -i "$COMPONENTS_DIR/Common/" --debug all -svlog ../$1 -sv_lib dpi -s TestSnapshot 
python3 $TEST_SCRIPT &
#GENERATE TCL SIMULATION SCRIPT
python3 "$SCRIPT_DIR/generate_sim_tcl.py" "20us"

#RUN SIMULATION
if [ -z "$2" ] ; then
  xsim TestSnapshot -t run_sim.tcl
elif [ $2 = "--gui" ] ; then
  xsim TestSnapshot --gui
fi

#CLEAN UP AFTERWARDS
cd ../
#rm -r  build