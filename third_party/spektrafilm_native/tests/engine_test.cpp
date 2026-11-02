#include "../include/spektrafilm/engine.hpp"

#include <cmath>
#include <cstdio>
#include <string>

int main(int argc, char** argv) {
    if (argc < 2) {
        std::printf("usage: engine_test <data-dir> [stock] [paper]\n");
        return 1;
    }
    try {
        spektrafilm::Engine engine(argv[1]);
        const auto stocks = engine.stocks();
        const auto papers = engine.papers();
        std::printf("stocks=%zu papers=%zu\n", stocks.size(), papers.size());
        for (const auto& stock : stocks) {
            std::printf("  stock %s | %s | %s | %s\n", stock.id.c_str(),
                        stock.name.c_str(), stock.targetPrint.c_str(),
                        stock.use.c_str());
        }
        for (const auto& paper : papers) {
            std::printf("  paper %s | %s\n", paper.id.c_str(), paper.name.c_str());
        }

        spektrafilm::Settings settings;
        settings.stockId = argc > 2 ? argv[2] : "kodak_portra_400";
        settings.paperId = argc > 3 ? argv[3] : "kodak_portra_endura";
        settings.grain = false;
        settings.dirCouplers = false;
        settings.halation = false;

        spektrafilm::Image image(32, 32);
        for (int y = 0; y < image.height; ++y) {
            for (int x = 0; x < image.width; ++x) {
                const float value = static_cast<float>(x) / 31.0f;
                image.at(x, y) = {value, value, value};
            }
        }
        const auto out = engine.render(image, settings);
        for (int x = 0; x < 32; x += 8) {
            const auto& p = out.at(x, 0);
            std::printf("x=%2d -> %.4f %.4f %.4f\n", x, p.r, p.g, p.b);
        }
    } catch (const std::exception& error) {
        std::printf("error: %s\n", error.what());
        return 2;
    }
    return 0;
}
