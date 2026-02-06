#!/bin/bash

TOP="sigma_delta_modulator_tb"
INC_DIR="/home/vivado/hdl/public/Components/Common"
OUT_DIR="sim_build"

rm -rf $OUT_DIR
mkdir $OUT_DIR

xvlog -sv /home/vivado/hdl/public/Components/Common/interfaces.sv rtl/*.sv tb/*.sv  -i $INC_DIR -log $OUT_DIR/compile.log

xelab -debug typical -top $TOP -snapshot sim_snapshot -log $OUT_DIR/elab.log

xsim sim_snapshot -tclbatch tb/sim.tcl
