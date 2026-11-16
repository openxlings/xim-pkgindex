import std;
int main() {
    std::vector<int> v{1, 2, 3};
    std::println("base-std {}", std::ranges::fold_left(v, 0, std::plus{}));
    return 44;
}
