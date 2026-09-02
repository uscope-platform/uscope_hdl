#include <iostream>
#include <fstream>
#include <cstdlib>

int main(int argc, char* argv[]) {
    // Default test value is 5, or pass one via CLI: ./app 12
    int val_to_send = (argc > 1) ? std::atoi(argv[1]) : 5;
    int val_received = 0;

    std::cout << "[C++ App] Opening pipe and sending: " << val_to_send << "..." << std::endl;

    // 1. Write to SystemVerilog
    std::ofstream pipe_out("in_pipe");
    if (!pipe_out.is_open()) {
        std::cerr << "Failed to open in_pipe!" << std::endl;
        return 1;
    }
    pipe_out << val_to_send << std::endl;
    pipe_out.close();
    if(val_to_send == 666) return 0;
    // 2. Read result back from SystemVerilog
    std::ifstream pipe_in("out_pipe");
    if (!pipe_in.is_open()) {
        std::cerr << "Failed to open out_pipe!" << std::endl;
        return 1;
    }
    pipe_in >> val_received;
    pipe_in.close();

    std::cout << "[C++ App] Success! Output from FPGA xsim: " << val_received << std::endl;
    return 0;
}