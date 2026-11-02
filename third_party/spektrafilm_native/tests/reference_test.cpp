#include "../include/spektrafilm/engine.hpp"

#include <cmath>
#include <cstdio>

namespace {
struct Expectation {
    float input;
    float r, g, b;
};
// Reference values produced by the upstream Python pipeline at the pinned
// commit (Kodak Portra 400 + Portra Endura, DIR couplers on, no grain,
// no spatial effects).
const Expectation kReference[] = {
    {0.020f, 0.07096f, 0.07990f, 0.08224f},
    {0.184f, 0.46071f, 0.46055f, 0.46038f},
    {0.500f, 0.71688f, 0.72882f, 0.73272f},
    {1.000f, 0.81714f, 0.82137f, 0.82040f},
};
} // namespace

int main(int argc, char** argv) {
    if (argc < 2) {
        std::printf("usage: reference_test <data-dir>\n");
        return 1;
    }
    int failures = 0;
    try {
        spektrafilm::Engine engine(argv[1]);
        spektrafilm::Settings settings;
        settings.stockId = "kodak_portra_400";
        settings.paperId = "kodak_portra_endura";
        settings.grain = false;
        settings.halation = false;
        settings.dirCouplers = true;

        for (const auto& expected : kReference) {
            spektrafilm::Image image(1, 1);
            image.at(0, 0) = {expected.input, expected.input, expected.input};
            const auto out = engine.render(image, settings);
            const auto& value = out.at(0, 0);
            const float dr = std::fabs(value.r - expected.r);
            const float dg = std::fabs(value.g - expected.g);
            const float db = std::fabs(value.b - expected.b);
            const bool ok = dr < 0.01f && dg < 0.01f && db < 0.01f;
            std::printf("%.3f | native %.5f %.5f %.5f | ref %.5f %.5f %.5f | %s\n",
                        expected.input, value.r, value.g, value.b,
                        expected.r, expected.g, expected.b, ok ? "ok" : "FAIL");
            if (!ok) ++failures;
        }
    } catch (const std::exception& error) {
        std::printf("error: %s\n", error.what());
        return 2;
    }
    return failures == 0 ? 0 : 1;
}
