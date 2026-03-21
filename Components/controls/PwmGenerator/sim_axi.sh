FILES=( 
    /home/vivado/hdl/public/Components/Common/interfaces.sv
    /home/vivado/hdl/public/Components/controls/PwmGenerator/rtl/ChainControlUnit.sv
    /home/vivado/hdl/public/Components/controls/PwmGenerator/rtl/CompareUnit.sv
    /home/vivado/hdl/public/Components/controls/PwmGenerator/rtl/Counter.sv
    /home/vivado/hdl/public/Components/controls/PwmGenerator/rtl/CounterCore.sv
    /home/vivado/hdl/public/Components/controls/PwmGenerator/rtl/CounterEnableDelayCore.sv
    /home/vivado/hdl/public/Components/controls/PwmGenerator/rtl/DeadTimeGenerator.sv
    /home/vivado/hdl/public/Components/controls/PwmGenerator/rtl/PinControl.sv
    /home/vivado/hdl/public/Components/controls/PwmGenerator/rtl/PwmControlUnit.sv
    /home/vivado/hdl/public/Components/controls/PwmGenerator/rtl/PwmGenerator.sv
    /home/vivado/hdl/public/Components/controls/PwmGenerator/rtl/ResolutionEnhancer.sv
    /home/vivado/hdl/public/Components/controls/PwmGenerator/rtl/SyncEngine.sv
    /home/vivado/hdl/public/Components/controls/PwmGenerator/rtl/TimebaseGenerator.sv
    /home/vivado/hdl/public/Components/controls/PwmGenerator/rtl/pwmChain.sv
    /home/vivado/hdl/public/Components/system/axi_lite/crossbar/rtl/address_decoder.sv
    /home/vivado/hdl/public/Components/system/axi_lite/crossbar/rtl/axil_crossbar.sv
    /home/vivado/hdl/public/Components/system/axi_lite/crossbar/rtl/axil_crossbar_wrapper.sv
    /home/vivado/hdl/public/Components/system/axi_lite/external_registers_cu/rtl/axil_external_registers_cu.sv
    /home/vivado/hdl/public/Components/system/axi_lite/skid_buffer/rtl/axil_skid_buffer.sv
    /opt/Xilinx/2025.2/Vivado/data/verilog/src/glbl.v
    /home/vivado/hdl/public/Components/controls/PwmGenerator/tb/pwm_generator_multi_chain_tb.sv
    /home/vivado/hdl/public/Components/system/axi_lite/axis_to_axil/rtl/axis_to_axil.sv
    /home/vivado/hdl/public/Components/system/axi_stream/skid_buffer/rtl/axis_skid_buffer.sv
)

mkdir -p /home/vivado/hdl/public/Components/controls/PwmGenerator/sim
cp sim.tcl /home/vivado/hdl/public/Components/controls/PwmGenerator/sim/sim.tcl


(
    cd /home/vivado/hdl/public/Components/controls/PwmGenerator/sim|| exit

    echo -e "\n\033[1;33m>>> PHASE 1: XVLOG (Analysis) <<<\033[0m"
    xvlog -sv "${FILES[@]}" -i /home/vivado/hdl/public/Components/Common -i /opt/Xilinx/2025.2/Vivado/data/rsb/busdef
    if [ $? -ne 0 ]; then
        echo -e "\033[1;31m!!! XVLOG FAILED !!!\033[0m"
        exit 1
    fi

    echo -e "\n\033[1;33m>>> PHASE 2: XELAB (Elaboration) <<<\033[0m"
    xelab -debug typical --relax -top pwm_generator_multi_chain_tb -top glbl -L xil_defaultlib -L unisims_ver -L unimacro_ver -L xpm  -snapshot sim_snapshot  -timescale 10ns/1ps
    if [ $? -ne 0 ]; then
        echo -e "\033[1;31m!!! XELAB FAILED !!!\033[0m"
        exit 1
    fi

    echo -e "\n\033[1;33m>>> PHASE 3: XSIM (Simulation) <<<\033[0m"
    xsim sim_snapshot -tclbatch sim.tcl
    if [ $? -ne 0 ]; then
        echo -e "\033[1;31m!!! XSIM FAILED !!!\033[0m"
        exit 1
    fi

)
if [ -f /home/vivado/hdl/public/Components/controls/PwmGenerator/sim/dump.vcd  ]; then
    vcd2fst /home/vivado/hdl/public/Components/controls/PwmGenerator/sim/dump.vcd dump.fst
    rm /home/vivado/hdl/public/Components/controls/PwmGenerator/sim/dump.vcd
fi
rm -r /home/vivado/hdl/public/Components/controls/PwmGenerator/sim
