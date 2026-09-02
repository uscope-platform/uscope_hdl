#!/bin/bash
source /software/2026.1/Vivado/settings64.sh
SOCKET_FILE="/tmp/fuzzing_socket.sock"
COMPONENTS="/home/fils/git/uplatform_hdl/public/Components"
CORE_RTL=$COMPONENTS/system/fcore/rtl
ISTORE_RTL=$COMPONENTS/system/fcore/istore/rtl
ALU_RTL=$COMPONENTS/system/fcore/alu
INCLUDE_DIR=$COMPONENTS/Common
trap 'kill $(jobs -p) 2>/dev/null; rm -f $SOCKET_FILE' EXIT
rm -f $SOCKET_FILE

echo "[1/4] Compiling SystemVerilog & DPI-C library..."
xsc dpi_socket.cpp || exit 1

echo "------------------------------------------------"
echo "                 HDL PARSING                    "
echo "------------------------------------------------"

xvhdl --nolog $ALU_RTL/ip/gen/adder_impl.vhd
xvhdl --nolog $ALU_RTL/ip/gen/fti_impl.vhd
xvhdl --nolog $ALU_RTL/ip/gen/itf_impl.vhd
xvhdl --nolog $ALU_RTL/ip/gen/mul_impl.vhd
xvhdl --nolog $ALU_RTL/ip/gen/rec_impl.vhd
xvlog -sv --nolog -i /software/2026.1/data/rsb/busdef $ALU_RTL/ip/gen/adder_sv.sv
xvlog -sv --nolog -i /software/2026.1/data/rsb/busdef $ALU_RTL/ip/gen/fti_sv.sv
xvlog -sv --nolog -i /software/2026.1/data/rsb/busdef $ALU_RTL/ip/gen/itf_sv.sv
xvlog -sv --nolog -i /software/2026.1/data/rsb/busdef $ALU_RTL/ip/gen/mul_sv.sv
xvlog -sv --nolog -i /software/2026.1/data/rsb/busdef $ALU_RTL/ip/gen/rec_sv.sv

xvlog -sv --nolog /home/fils/git/uplatform_hdl/public/Components/Common/interfaces.sv
xvlog -sv --nolog -i $INCLUDE_DIR $CORE_RTL/fCore_ISA.sv
xvlog -sv --nolog /software/2026.1/Vivado/data/verilog/src/glbl.v


xvlog -sv --nolog -i $INCLUDE_DIR $COMPONENTS/system/axi_stream/register_slice/rtl/register_slice.sv
xvlog -sv --nolog -i $INCLUDE_DIR $COMPONENTS/system/axi_lite/skid_buffer/rtl/axil_skid_buffer.sv
xvlog -sv --nolog -i $INCLUDE_DIR $COMPONENTS/system/axi_stream/fifo/rtl/axis_fifo_xpm.sv
xvlog -sv --nolog -i $INCLUDE_DIR $COMPONENTS/Common/DP_RAM.sv
xvlog -sv --nolog -i $INCLUDE_DIR -i /software/2026.1/data/rsb/busdef $COMPONENTS/Adapters/amd_axi_stream_converter_master.sv
xvlog -sv --nolog -i $INCLUDE_DIR -i /software/2026.1/data/rsb/busdef $COMPONENTS/Adapters/amd_axi_stream_converter_slave.sv
xvlog -sv --nolog -i $INCLUDE_DIR $COMPONENTS/system/axi_lite/external_registers_cu/rtl/axil_external_registers_cu.sv
xvlog -sv --nolog -i $INCLUDE_DIR $ALU_RTL/ip/fcore_adder_ip.sv
xvlog -sv --nolog -i $INCLUDE_DIR $ALU_RTL/ip/fcore_fti_ip.sv
xvlog -sv --nolog -i $INCLUDE_DIR $ALU_RTL/ip/fcore_itf_ip.sv
xvlog -sv --nolog -i $INCLUDE_DIR $ALU_RTL/ip/fcore_multiplier_ip.sv
xvlog -sv --nolog -i $INCLUDE_DIR $ALU_RTL/ip/fcore_reciprocal_ip.sv
xvlog -sv --nolog -i $INCLUDE_DIR $ALU_RTL/rtl/alu_results_combiner.sv
xvlog -sv --nolog -i $INCLUDE_DIR $ALU_RTL/rtl/FP_saturator.sv
xvlog -sv --nolog -i $INCLUDE_DIR $ISTORE_RTL/fCore_Istore.sv
xvlog -sv --nolog -d SIMULATION_TRACE -i INCLUDE_DIR $ISTORE_RTL/istore_axi_interface.sv
xvlog -sv --nolog -i $INCLUDE_DIR $ISTORE_RTL/istore_memory.sv
xvlog -sv --nolog -i $INCLUDE_DIR $CORE_RTL/fCore_ControlUnit.sv
xvlog -sv --nolog -i $INCLUDE_DIR $CORE_RTL/fCore_compare_unit.sv
xvlog -sv --nolog -i $INCLUDE_DIR $CORE_RTL/fCore_decoder.sv
xvlog -sv --nolog -i $INCLUDE_DIR $CORE_RTL/fCore_tracer.sv
xvlog -sv --nolog -i $INCLUDE_DIR $CORE_RTL/fCore_pipeline_tracker.sv
xvlog -sv --nolog -i $INCLUDE_DIR $CORE_RTL/fCore_FP_ALU.sv
xvlog -sv --nolog -i $INCLUDE_DIR $CORE_RTL/fCore_dma_endpoint.sv
xvlog -sv --nolog -i $INCLUDE_DIR $CORE_RTL/fCore_registerFile.sv
xvlog -sv --nolog -i $INCLUDE_DIR $CORE_RTL/fcore_common_io.sv
xvlog -sv --nolog -i $INCLUDE_DIR $CORE_RTL/fCore.sv
xvlog -sv --nolog -i $INCLUDE_DIR $CORE_RTL/fCore_logic_unit.sv
xvlog -sv --nolog -i $INCLUDE_DIR $CORE_RTL/fCore_efi_memory_handler.sv
xvlog -sv --nolog -i $INCLUDE_DIR $CORE_RTL/fCore_bitmanip_unit.sv

xvlog -sv --nolog -i $INCLUDE_DIR fuzzing_server.sv
xvlog -sv --nolog -i $INCLUDE_DIR fuzzing_tb.sv || exit 1
xelab fuzzing_tb  --relax -top glbl -L xil_defaultlib -L unisims_ver -L unimacro_ver -L xpm --nolog -sv_lib dpi -s top_sim || exit 1


echo "------------------------------------------------"
echo "              C++ COMPILATION                   "
echo "------------------------------------------------"

echo "[2/4] Compiling C++ client app..."
g++ fuzzing_test.cpp -o app || exit 1

echo "------------------------------------------------"
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