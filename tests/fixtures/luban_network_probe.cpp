#include <arpa/inet.h>
#include <sys/socket.h>
#include <unistd.h>
#include <cerrno>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <string>

#ifndef HOST_SERVICE_PORT
#define HOST_SERVICE_PORT 7897
#endif

static bool read_exact(int fd, void* data, size_t size) {
    auto* p = static_cast<char*>(data);
    while (size) {
        auto n = recv(fd, p, size, 0);
        if (n <= 0) return false;
        p += n; size -= n;
    }
    return true;
}
static int tcp(const char* host, unsigned port) {
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    timeval timeout{4, 0};
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));
    sockaddr_in address{};
    address.sin_family = AF_INET; address.sin_port = htons(port);
    inet_pton(AF_INET, host, &address.sin_addr);
    if (connect(fd, reinterpret_cast<sockaddr*>(&address), sizeof(address))) { close(fd); return -1; }
    return fd;
}
int main(int argc, char** argv) {
    if (argc != 2) return 2;
    if (std::string(argv[1]) == "direct") {
        int remote = tcp("192.0.2.1", 80);
        int loopback = tcp("127.0.0.1", HOST_SERVICE_PORT);
        int dns = socket(AF_INET, SOCK_DGRAM, 0);
        sockaddr_in server{}; server.sin_family = AF_INET; server.sin_port = htons(53);
        inet_pton(AF_INET, "208.67.222.222", &server.sin_addr);
        bool dns_blocked = sendto(dns, "probe", 5, 0, reinterpret_cast<sockaddr*>(&server), sizeof(server)) < 0;
        close(dns);
        int v6 = socket(AF_INET6, SOCK_DGRAM, 0);
        bool v6_blocked = v6 < 0;
        if (v6 >= 0) {
            sockaddr_in6 address{}; address.sin6_family = AF_INET6; address.sin6_port = htons(53);
            inet_pton(AF_INET6, "2001:db8::1", &address.sin6_addr);
            v6_blocked = sendto(v6, "probe", 5, 0, reinterpret_cast<sockaddr*>(&address), sizeof(address)) < 0;
            close(v6);
        }
        if (remote >= 0) close(remote);
        if (loopback >= 0) close(loopback);
        if (remote >= 0 || loopback >= 0 || !dns_blocked || !v6_blocked) return 1;
        std::cout << "direct TCP, host loopback, UDP DNS and IPv6 blocked\n";
        return 0;
    }
    const char* proxy = std::getenv("ALL_PROXY");
    if (!proxy) return 3;
    std::string endpoint(proxy);
    auto colon = endpoint.rfind(':');
    if (colon == std::string::npos) return 3;
    int fd = tcp("127.0.0.1", std::stoul(endpoint.substr(colon + 1)));
    if (fd < 0) return 4;
    unsigned char hello[]{5, 1, 0}, response[4];
    send(fd, hello, 3, 0);
    if (!read_exact(fd, response, 2) || response[0] != 5 || response[1] != 0) return 5;
    std::string domain = "example.com";
    std::string request("\5\1\0\3", 4);
    request += static_cast<char>(domain.size()); request += domain; request += '\0'; request += '\120';
    send(fd, request.data(), request.size(), 0);
    if (!read_exact(fd, response, 4) || response[0] != 5 || response[1] != 0) return 6;
    char bound[258]; size_t bound_size = 0;
    if (response[3] == 1) bound_size = 6;
    else if (response[3] == 4) bound_size = 18;
    else if (response[3] == 3) { unsigned char size; if (!read_exact(fd, &size, 1)) return 7; bound_size = size + 2; }
    else return 7;
    if (!read_exact(fd, bound, bound_size)) return 7;
    const char* http = "GET / HTTP/1.0\r\nHost: example.com\r\n\r\n";
    send(fd, http, std::strlen(http), 0);
    char header[128]{};
    auto count = recv(fd, header, sizeof(header) - 1, 0);
    close(fd);
    if (count <= 0 || std::string(header).find("HTTP/") != 0) return 8;
    std::cout << "SOCKS5h remote-name HTTP: " << std::string(header).substr(0, std::string(header).find('\r')) << '\n';
}
