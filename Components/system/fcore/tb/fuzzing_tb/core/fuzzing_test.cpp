#include <iostream>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <cstdlib>
#include <cstring>
#include <chrono>
#include <thread>
#include "fuzz_types.h"

static const char* SOCKET_PATH = "/tmp/fuzzing_socket.sock";




static bool read_exact(int fd, void* buffer, size_t length) {
    size_t total_read = 0;
    char* ptr = static_cast<char*>(buffer);
    
    while (total_read < length) {
        ssize_t bytes = read(fd, ptr + total_read, length - total_read);
        if (bytes <= 0) return false;
        total_read += bytes;
    }
    return true;
}

static bool write_exact(int fd, const void* buffer, size_t length) {
    size_t total_written = 0;
    const char* ptr = static_cast<const char*>(buffer);
    
    while (total_written < length) {
        ssize_t bytes = write(fd, ptr + total_written, length - total_written);
        if (bytes <= 0) return false;
        total_written += bytes;
    }
    return true;
}

int connect_with_retry(int sock, const sockaddr_un& addr, int max_retries = 50, int delay_ms = 300) {
    for (int attempt = 0; attempt < max_retries; ++attempt) {
        if (connect(sock, (struct sockaddr*)&addr, sizeof(addr)) == 0) {
            return 0; // Success
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(delay_ms));
    }
    return -1; // Failed after retries
}

int main(int argc, char* argv[]) {
    int val_to_send = (argc > 1) ? std::atoi(argv[1]) : 5;
    int val_received = 0;

    int sock = socket(AF_UNIX, SOCK_STREAM, 0);
    if (sock < 0) {
        std::cerr << "Failed to create socket!" << std::endl;
        return 1;
    }

    sockaddr_un addr{};
    addr.sun_family = AF_UNIX;
    std::strncpy(addr.sun_path, SOCKET_PATH, sizeof(addr.sun_path) - 1);

    // Retry connection until xsim server is ready
    if (connect_with_retry(sock, addr) < 0) {
        std::cerr << "Failed to connect to xsim socket (timed out waiting for simulator)!" << std::endl;
        close(sock);
        return 1;
    }
    
    std::cout << "--------------------------TEST START--------------------------"<< std::endl;
    fuzzing_package pkg;
    for(int i = 0; i<64; i++)
        pkg.reg_file[i] = 0;
    for(int i = 0; i<4096; i++)
        pkg.instructions[i] = 0;

    pkg.instructions[0] = 124;
    pkg.instructions[1] = 324;
    pkg.instructions[2] = 12;

    pkg.reg_file[1] = 67;
    pkg.reg_file[2] = 68;
    pkg.reg_file[3] = 69;

    // 1. Send integer payload directly
    write(sock, &pkg, sizeof(pkg));

    // 2. Read back result payload directly
    read(sock, &val_received, sizeof(val_received));

    for(int i = 0; i<64; i++)
        pkg.reg_file[i] = 0;
    for(int i = 0; i<4096; i++)
        pkg.instructions[i] = 0;

    // Read back the execution result buffer
    fuzz_result res{};
    read_exact(sock, &res, sizeof(res));
    std::cout << "[C++ Client] Received execution result reg[0]: " 
          << std::hex << res.reg_file[0] << std::dec << std::endl;

    int ack_to_sv = 1;
    write(sock, &ack_to_sv, sizeof(ack_to_sv));
    
    pkg.reg_file[0] = 666;

    // 1. Send integer payload directly
    write(sock, &pkg, sizeof(pkg));

    // 2. Read back result payload directly
    read(sock, &val_received, sizeof(val_received));
    close(sock);

    std::cout << "--------------------------TEST END--------------------------"<< std::endl;

    std::cout << "[C++ App] Success! Output from FPGA xsim: " << val_received << std::endl;
    return 0;
}