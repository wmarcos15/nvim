// Sample for scripts/check.lua.
#include <string>
#include <vector>

class Greeter {
public:
    explicit Greeter(std::string name) : name_(std::move(name)) {}
    std::string greet(int times, bool shout) const {
        std::string out;
        for (int i = 0; i < times; ++i) {
            if (shout) out += "HELLO " + name_; else out += "hello " + name_;
        }
        return out;
    }
private:
    std::string name_;
};

int main() {
    std::vector<Greeter> all{Greeter("a"), Greeter("b")};
    return static_cast<int>(all.front().greet(2, false).size());
}
