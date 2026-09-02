#!/bin/bash
source /software/2026.1/Vivado/settings64.sh
# Clean up background jobs and temporary files on exit
trap 'kill $(jobs -p) 2>/dev/null; rm -f in_pipe out_pipe xsim_out.log' EXIT

mkfifo in_pipe out_pipe

echo "[2/4] Compiling SystemVerilog..."
xvlog -sv --nolog fuzzing_tb_fifo.sv || exit 1
xelab fuzzing_tb_fifo --nolog -s  top_sim   || exit 1

echo "[3/4] Compiling C++ app FIRST..."
g++ fuzzing_test_fifo.cpp -o app || exit 1

echo "[4/4] Launching xsim in background..."
# Redirect output to prevent background stdout buffering hangs
xsim top_sim -R --nolog 2>&1 &
XSIM_PID=$!

echo "=========================================="
echo " Running C++ Application Tests "
echo "=========================================="

./app 7
./app 42
./app 100
./app 666

# Wait for xsim to shut down cleanly
wait $XSIM_PID 2>/dev/null

rm -r xsim.dir
rm -f in_pipe out_pipe xsim_out.log app *.pb *.jou
echo "Done!"