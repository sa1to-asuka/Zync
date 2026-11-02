#include "../include/spektrafilm/engine.hpp"

#include <cstdio>
#include <fstream>

namespace {
struct Case {
    const char* id;
    const char* stock;
    float amount;
    float scale;
    float strength[3]; // -1 = use the profile preset
    float sigmaUm; // <= 0 = use the profile preset
    float scatter; // < 0 = default 1.0
};
const Case kCases[] = {
    {"strong_1.0_1.0", "kodak_portra_400", 1.0f, 1.0f, {-1, -1, -1}, -1, -1},
    {"strong_2.0_1.0", "kodak_portra_400", 2.0f, 1.0f, {-1, -1, -1}, -1, -1},
    {"strong_1.0_2.0", "kodak_portra_400", 1.0f, 2.0f, {-1, -1, -1}, -1, -1},
    {"weak_1.0_1.0", "kodak_gold_200", 1.0f, 1.0f, {-1, -1, -1}, -1, -1},
    {"cine_1.0_1.0", "kodak_vision3_500t", 1.0f, 1.0f, {-1, -1, -1}, -1, -1},
    {"no_preset", "kodak_portra_400", 1.0f, 1.0f, {0.30f, 0.10f, 0.015f}, 65.0f, -1},
    {"off", "kodak_portra_400", 0.0f, 1.0f, {-1, -1, -1}, -1, -1},
    {"scatter_only", "kodak_portra_400", 1.0f, 1.0f, {0.0f, 0.0f, 0.0f}, 65.0f, -1},
    {"halation_only", "kodak_portra_400", 1.0f, 1.0f, {0.30f, 0.10f, 0.015f}, 65.0f, 0.0f},
};
constexpr int kSize = 257;
constexpr int kSpot = 5;
constexpr float kBackground = 0.02f;
constexpr float kSpotValue = 3.0f;
constexpr float kPixelSizeUm = 8.0f;
} // namespace

int main(int argc, char** argv) {
    if (argc < 3) {
        std::printf("usage: halation_dump <data-dir> <out-tsv>\n");
        return 1;
    }
    try {
        spektrafilm::Engine engine(argv[1]);
        std::ofstream out(argv[2], std::ios::binary);
        if (!out) return 1;
        for (const auto& test : kCases) {
            spektrafilm::Settings settings;
            settings.stockId = test.stock;
            settings.paperId = "kodak_portra_endura";
            settings.grain = false;
            settings.dirCouplers = false;
            settings.halationAmount = test.amount;
            settings.halationSpatialScale = test.scale;
            settings.pixelSizeUm = kPixelSizeUm;
            for (int c = 0; c < 3; ++c) {
                settings.halationStrengthOverride[c] = test.strength[c];
            }
            settings.halationSigmaUmOverride = test.sigmaUm;
            settings.halationScatterAmountOverride = test.scatter;
            spektrafilm::Image image(kSize, kSize);
            for (int y = 0; y < kSize; ++y) {
                for (int x = 0; x < kSize; ++x) {
                    const bool spot = x >= 128 && x < 128 + kSpot
                        && y >= 128 && y < 128 + kSpot;
                    const float value = spot ? kSpotValue : kBackground;
                    image.at(x, y) = {value, value, value};
                }
            }
            const auto exposed =
                engine.exposeFilm(image, settings, engine.profile(test.stock));
            for (int y = 113; y <= 143; ++y) {
                for (int x = 113; x <= 143; ++x) {
                    const auto& v = exposed.at(x, y);
                    out << test.id << '\t' << x << '\t' << y << '\t'
                        << v.r << '\t' << v.g << '\t' << v.b << '\n';
                }
            }
        }
        std::printf("wrote %s\n", argv[2]);
    } catch (const std::exception& error) {
        std::printf("error: %s\n", error.what());
        return 2;
    }
    return 0;
}
