#include <iostream>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <cstring>
#include "svdpi.h"

static const char* SOCKET_PATH = "/tmp/fuzzing_socket.sock";
static int server_fd = -1;
static int client_fd = -1;

extern "C" {

    // Called once at the start of simulation to create the socket server
    int init_socket_server() {
        unlink(SOCKET_PATH); // Clean up any previous stale socket file

        server_fd = socket(AF_UNIX, SOCK_STREAM, 0);
        if (server_fd < 0) {
            perror("[DPI-C] Socket creation failed");
            return -1;
        }

        sockaddr_un addr{};
        addr.sun_family = AF_UNIX;
        std::strncpy(addr.sun_path, SOCKET_PATH, sizeof(addr.sun_path) - 1);

        if (bind(server_fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
            perror("[DPI-C] Bind failed");
            return -1;
        }

        if (listen(server_fd, 1) < 0) {
            perror("[DPI-C] Listen failed");
            return -1;
        }

        std::cout << "[DPI-C] Socket server initialized at " << SOCKET_PATH << std::endl;
        return 0;
    }

    // Blocking function: waits for C++ client, receives input, sends output
    int process_transaction(int dut_out, int* dut_in) {
        client_fd = accept(server_fd, nullptr, nullptr);
        if (client_fd < 0) {
            perror("[DPI-C] Accept failed");
            return -1;
        }

        // Read incoming integer from C++ client
        int received_val = 0;
        ssize_t bytes_read = read(client_fd, &received_val, sizeof(received_val));
        if (bytes_read <= 0) {
            close(client_fd);
            return -1;
        }

        *dut_in = received_val;

        // If termination command (666), do not write response back
        if (received_val == 666) {
            close(client_fd);
            return 666;
        }

        // Send output response back to C++ client
        write(client_fd, &dut_out, sizeof(dut_out));

        close(client_fd);
        return 0; // Success
    }

    // Cleanup server socket on simulation end
    void cleanup_socket_server() {
        if (server_fd >= 0) close(server_fd);
        unlink(SOCKET_PATH);
    }
}