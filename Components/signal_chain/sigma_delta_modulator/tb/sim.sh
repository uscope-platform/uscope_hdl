#!/bin/bash


PROJ_ROOT=$(pwd)
BUILD_DIR="$PROJ_ROOT/sim"
TOP="sigma_delta_modulator_tb"
INC_DIR=$(realpath "../../Common/")
SIM_FILE=$(realpath "tb/sim.tcl")


# List of files to compile
FILES=(
    "../../Common/interfaces.sv"
    "rtl/*.sv"
    "tb/*.sv"
    "../SigmaDeltaProcessor/rtl/*.sv"
    "../../system/axi_lite/simple_register_cu/rtl/*.sv"
    "../../system/axi_lite/skid_buffer/rtl/*.sv"
    "../../system/axi_stream/combiner/rtl/*.sv"
)

FILES_EXPANDED=$(realpath ${FILES[@]})

mkdir -p $BUILD_DIR
(
    cd "$BUILD_DIR" || exit

    xvlog -sv $FILES_EXPANDED -i $INC_DIR

    xelab -debug typical -top $TOP -snapshot sim_snapshot  -timescale 10ns/1ps

    xsim sim_snapshot -tclbatch $SIM_FILE 

)

