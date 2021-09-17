#!/bin/bash

# Check if arguments have been supplied
if [ -z "$1" ]
  then
    echo "No argument supplied"
    exit 1
fi

#SETUP BUILD DIRECTORY AND VARIABLES
mkdir -p build
cd build

BASE_DIR="../../../.."
SOCK_DIR="$BASE_DIR/sock"
COMPONENTS_DIR="$BASE_DIR/Components"
SCRIPT_DIR="$BASE_DIR/script"
SIM_SOURCES="$COMPONENTS_DIR/PwmGenerator/rtl/* $COMPONENTS_DIR/Common/RegisterFile.v $COMPONENTS_DIR/SimplebusInterconnect/rtl/*"



# "COMPILE" SYSTEM VERILOG FILES
xvlog -i "$COMPONENTS_DIR/Common/" -sv $SIM_SOURCES ../$1

#SETUP SIMULATION
xelab -i "$COMPONENTS_DIR/Common/" --debug all -svlog ../$1 -s TestSnapshot 
#GENERATE TCL SIMULATION SCRIPT
python "$SCRIPT_DIR/generate_sim_tcl.py" "20us"

#RUN SIMULATION
if [ -z "$2" ] ; then
  xsim TestSnapshot -t run_sim.tcl
elif [ $2 = "--gui" ] ; then
  xsim TestSnapshot --gui
fi

#CLEAN UP AFTERWARDS
cd ../
rm -r  build