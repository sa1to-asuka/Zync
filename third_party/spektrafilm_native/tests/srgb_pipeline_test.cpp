#include "../include/spektrafilm/engine.hpp"
#include <cmath>
#include <cstdio>

int main(int argc, char** argv) {
    if (argc < 2) return 1;
    spektrafilm::Engine engine(argv[1]);
    const int w = 512, h = 384;
    spektrafilm::Image image(w, h);
    for (int y = 0; y < h; ++y) {
        for (int x = 0; x < w; ++x) {
            const float u = static_cast<float>(x) / w;
            const float v = static_cast<float>(y) / h;
            image.at(x, y) = spektrafilm::Engine::srgbToProPhoto(
                {0.1f + 0.8f * u, 0.1f + 0.7f * v, 0.5f - 0.4f * u + 0.2f * v});
        }
    }
    spektrafilm::Settings s;
    s.stockId = "fujifilm_pro_400h";
    s.paperId = "fujifilm_crystal_archive_typeii";
    const auto out = engine.render(image, s);
    double sum = 0, sq = 0, mn = 1e9, mx = -1e9;
    for (int i = 0; i < w * h; ++i) {
        const double v = out.rgb[i * 3 + 1];
        sum += v; sq += v * v; mn = std::min(mn, v); mx = std::max(mx, v);
    }
    const double n = w * h, mean = sum / n;
    const double sd = std::sqrt(std::max(sq / n - mean * mean, 0.0));
    std::printf("srgb->film: mean %.3f std %.3f min %.3f max %.3f\n", mean, sd, mn, mx);
    return (sd > 0.05 && mean < 0.95) ? 0 : 1;
}
