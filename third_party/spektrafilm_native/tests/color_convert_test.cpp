#include "../include/spektrafilm/engine.hpp"
#include <cmath>
#include <cstdio>

int main() {
    struct Case { float in[3]; float out[3]; };
    const Case cases[] = {
        {{0.0f, 0.0f, 0.0f}, {0.0f, 0.0f, 0.0f}},
        {{0.184f, 0.184f, 0.184f}, {0.02834f, 0.02834f, 0.02834f}},
        {{0.5f, 0.5f, 0.5f}, {0.21403f, 0.21404f, 0.21409f}},
        {{1.0f, 1.0f, 1.0f}, {0.99996f, 1.00001f, 1.00021f}},
        {{0.8f, 0.2f, 0.1f}, {0.33192f, 0.08859f, 0.02276f}},
    };
    int failures = 0;
    for (const auto& test : cases) {
        const auto out = spektrafilm::Engine::srgbToProPhoto(
            {test.in[0], test.in[1], test.in[2]});
        for (int c = 0; c < 3; ++c) {
            const float error = std::fabs(out[c] - test.out[c]);
            if (error > 1e-3f) {
                std::printf("FAIL in=%g,%g,%g ch%d native=%.5f expected=%.5f\n",
                            test.in[0], test.in[1], test.in[2], c, out[c], test.out[c]);
                ++failures;
            }
        }
    }
    std::printf(failures == 0 ? "color conversion ok\n" : "color conversion failed\n");
    return failures == 0 ? 0 : 1;
}
