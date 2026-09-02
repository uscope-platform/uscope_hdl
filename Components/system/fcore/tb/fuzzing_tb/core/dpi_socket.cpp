#include <iostream>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <cstring>
#include <cstdint>
#include "svdpi.h"

static const char* SOCKET_PATH = "/tmp/fuzzing_socket.sock";
static int server_fd = -1;
static int client_fd = -1;

struct fuzzing_package {
    uint32_t reg_file[64];
    uint32_t instructions[4096];
};

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

extern "C" {

    int init_socket_server() {
        unlink(SOCKET_PATH);

        server_fd = socket(AF_UNIX, SOCK_STREAM, 0);
        if (server_fd < 0) return -1;

        sockaddr_un addr{};
        addr.sun_family = AF_UNIX;
        std::strncpy(addr.sun_path, SOCKET_PATH, sizeof(addr.sun_path) - 1);

        if (bind(server_fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) return -1;
        if (listen(server_fd, 1) < 0) return -1;

        std::cout << "[DPI-C] Socket server initialized at " << SOCKET_PATH << std::endl;
        client_fd = accept(server_fd, nullptr, nullptr);
        if (client_fd < 0) return -1;
        return 0;
    }

    // Direct write to SystemVerilog unpacked arrays via svOpenArrayHandle
    int process_transaction(const svOpenArrayHandle regs_h, const svOpenArrayHandle insts_h) {


        fuzzing_package pkg{};

        if (!read_exact(client_fd, &pkg, sizeof(pkg))) {
            close(client_fd);
            return -1;
        }

        // 1. Copy 64 registers directly into SV reg_file array
        int reg_low = svLow(regs_h, 1);
        for (int i = 0; i < 64; i++) {
            uint32_t* ptr = (uint32_t*)svGetArrElemPtr1(regs_h, reg_low + i);
            if (ptr) *ptr = pkg.reg_file[i];
        }

        // 2. Copy 4096 instructions directly into SV instructions array
        int inst_low = svLow(insts_h, 1);
        for (int i = 0; i < 4096; i++) {
            uint32_t* ptr = (uint32_t*)svGetArrElemPtr1(insts_h, inst_low + i);
            if (ptr) *ptr = pkg.instructions[i];
        }

        int ack = 1;
        write(client_fd, &ack, sizeof(ack));

        if (pkg.reg_file[0] == 666 )
            return 666;
        else 
            return 0;
    }

    void cleanup_socket_server() {
        if (client_fd >= 0) close(client_fd);
        if (server_fd >= 0) close(server_fd);
        unlink(SOCKET_PATH);
    }
}