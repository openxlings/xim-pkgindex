#include <print>
#include <stdexcept>
int main() {
    try { throw std::runtime_error("base-cxx"); }
    catch (const std::exception& e) { std::println("{}", e.what()); }
    return 43;
}
