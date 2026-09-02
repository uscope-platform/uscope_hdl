#!/bin/bash
source /software/2026.1/Vivado/settings64.sh
SOCKET_FILE="/tmp/fuzzing_socket.sock"

trap 'kill $(jobs -p) 2>/dev/null; rm -f $SOCKET_FILE' EXIT
rm -f $SOCKET_FILE

echo "[1/4] Compiling SystemVerilog & DPI-C library..."
xsc dpi_socket.cpp || exit 1
xvlog -sv --nolog fuzzing_server.sv fuzzing_tb.sv || exit 1
xelab fuzzing_tb --nolog -sv_lib dpi -s top_sim || exit 1

echo "[2/4] Compiling C++ client app..."
g++ fuzzing_test.cpp -o app || exit 1

echo "[3/4] Launching xsim background server..."
xsim top_sim -R --nolog 2>&1 &
XSIM_PID=$!

echo "=========================================="
echo " Running C++ Application Tests "
echo "=========================================="

# The first ./app call will automatically pause and wait for xsim to boot up
./app

wait $XSIM_PID 2>/dev/null

rm -rf xsim.dir app xsc.log *.pb *.jou
echo "Done!"