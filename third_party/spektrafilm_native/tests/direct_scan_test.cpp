#include "../include/spektrafilm/engine.hpp"
#include <algorithm>
#include <cmath>
#include <cstdio>

int main(int argc, char** argv) {
    if (argc < 2) return 1;
    spektrafilm::Engine engine(argv[1]);
    const int w = 256, h = 192;
    spektrafilm::Image image(w, h);
    for (int y = 0; y < h; ++y) {
        for (int x = 0; x < w; ++x) {
            const float u = static_cast<float>(x) / w;
            const float v = static_cast<float>(y) / h;
            image.at(x, y) = spektrafilm::Engine::srgbToProPhoto(
                {0.1f + 0.7f * u, 0.15f + 0.6f * v, 0.4f - 0.2f * u + 0.2f * v});
        }
    }

    spektrafilm::Settings settings;
    settings.stockId = "fujifilm_pro_400h";
    settings.paperId = "negative_direct_scan";
    settings.scanFilm = true;
    const auto out = engine.render(image, settings);

    double sum = 0, sq = 0;
    for (float value : out.rgb) {
        sum += value;
        sq += static_cast<double>(value) * value;
    }
    const double count = static_cast<double>(out.rgb.size());
    const double mean = sum / count;
    const double sd = std::sqrt(std::max(sq / count - mean * mean, 0.0));
    std::printf("direct scan: mean %.3f std %.3f\n", mean, sd);
    return sd > 0.02 ? 0 : 1;
}
