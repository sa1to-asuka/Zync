#include "../include/spektrafilm/engine.hpp"
#include <chrono>
#include <cmath>
#include <cstdio>

int main(int argc, char** argv) {
    if (argc < 2) return 1;
    try {
        spektrafilm::Engine engine(argv[1]);
        const int w = 1024, h = 768;
        spektrafilm::Image image(w, h);
        for (int y = 0; y < h; ++y) {
            for (int x = 0; x < w; ++x) {
                const float u = static_cast<float>(x) / w;
                const float v = static_cast<float>(y) / h;
                image.at(x, y) = {0.02f + 0.6f * u, 0.05f + 0.5f * v, 0.3f * (1 - u) + 0.2f};
            }
        }
        spektrafilm::Settings s;
        s.stockId = "fujifilm_pro_400h";
        s.paperId = "fujifilm_crystal_archive_typeii";
        const auto& film = engine.profile(s.stockId);
        const auto& paper = engine.profile(s.paperId);
        auto now = [] { return std::chrono::steady_clock::now(); };
        auto ms = [](auto a, auto b) {
            return std::chrono::duration<double, std::milli>(b - a).count();
        };
        const auto a0 = now();
        const auto exposed = engine.exposeFilm(image, s, film);
        const auto a1 = now();
        const auto density = engine.developFilm(exposed, s, film);
        const auto a2 = now();
        const auto printed = engine.printDensity(density, s, film, paper);
        const auto a3 = now();
        const auto scanned = engine.scan(printed, s, paper);
        const auto a4 = now();
        (void)scanned;
        std::printf("stages: expose %.0f, develop %.0f, print %.0f, scan %.0f\n",
                    ms(a0, a1), ms(a1, a2), ms(a2, a3), ms(a3, a4));
        const auto t0 = now();
        const auto out = engine.render(image, s);
        const auto t1 = now();
        const auto second = engine.render(image, s);
        const auto t2 = now();
        std::printf("first %.0f ms, cached %.0f ms\n",
            std::chrono::duration<double, std::milli>(t1 - t0).count(),
            std::chrono::duration<double, std::milli>(t2 - t1).count());
        (void)second;
        double mn[3] = {1e9, 1e9, 1e9}, mx[3] = {-1e9, -1e9, -1e9}, sum[3] = {0, 0, 0}, sq[3] = {0, 0, 0};
        for (int i = 0; i < w * h; ++i) {
            for (int c = 0; c < 3; ++c) {
                const double v = out.rgb[i * 3 + c];
                mn[c] = std::min(mn[c], v); mx[c] = std::max(mx[c], v);
                sum[c] += v; sq[c] += v * v;
            }
        }
        const double n = w * h;
        for (int c = 0; c < 3; ++c) {
            const double mean = sum[c] / n;
            const double var = sq[c] / n - mean * mean;
            std::printf("ch%d min=%.4f max=%.4f mean=%.4f std=%.4f\n", c, mn[c], mx[c], mean, std::sqrt(std::max(var, 0.0)));
        }
        for (int y = 0; y < h; y += 256) {
            for (int x = 0; x < w; x += 256) {
                const auto& p = out.at(x, y);
                std::printf("(%d,%d)=%.3f,%.3f,%.3f\n", x, y, p.r, p.g, p.b);
            }
        }
    } catch (const std::exception& e) {
        std::printf("error: %s\n", e.what());
        return 2;
    }
    return 0;
}
