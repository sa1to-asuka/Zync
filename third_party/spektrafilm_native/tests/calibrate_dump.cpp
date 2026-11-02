#include "../include/spektrafilm/engine.hpp"
#include "../src/data_io.hpp"

#include <cstdio>
#include <fstream>
#include <string>

int main(int argc, char** argv) {
    if (argc < 4) {
        std::printf("usage: calibrate_dump <data-dir> <patches-json> <out-csv>\n");
        return 1;
    }
    try {
        spektrafilm::Engine engine(argv[1]);
        const auto patchesRoot = spektrafilm::parseJson(spektrafilm::readText(argv[2]));
        const auto& patches = patchesRoot["patches"];
        std::ofstream out(argv[3], std::ios::binary);
        if (!out) return 1;

        for (const auto& stock : engine.stocks()) {
            const bool scan = stock.targetPrint.empty();
            const std::string paper = scan ? "kodak_portra_endura" : stock.targetPrint;
            spektrafilm::Settings settings;
            settings.stockId = stock.id;
            settings.paperId = paper;
            settings.scanFilm = scan;
            settings.grain = false;
            settings.halation = false;
            settings.dirCouplers = true;
            for (const auto& patch : patches.array) {
                const auto rgb = spektrafilm::jsonFloats(patch["rgb"]);
                if (rgb.size() < 3) continue;
                spektrafilm::Image image(1, 1);
                image.at(0, 0) = {rgb[0], rgb[1], rgb[2]};
                const auto& film = engine.profile(stock.id);
                const auto exposed = engine.exposeFilm(image, settings, film);
                const auto density = engine.developFilm(exposed, settings, film);
                const auto result = engine.render(image, settings);
                const auto& le = exposed.at(0, 0);
                const auto& d = density.at(0, 0);
                const auto& value = result.at(0, 0);
                spektrafilm::Vec3 pd = d;
                if (!scan) {
                    const auto& paperProfile = engine.profile(paper);
                    const auto printed =
                        engine.printDensity(density, settings, film, paperProfile);
                    pd = printed.at(0, 0);
                }
                out << stock.id << '\t' << paper << '\t' << (scan ? 1 : 0) << '\t'
                    << patch["name"].asString() << '\t'
                    << le.r << '\t' << le.g << '\t' << le.b << '\t'
                    << d.r << '\t' << d.g << '\t' << d.b << '\t'
                    << pd.r << '\t' << pd.g << '\t' << pd.b << '\t'
                    << value.r << '\t' << value.g << '\t' << value.b << '\n';
            }
        }
        std::printf("wrote %s\n", argv[3]);
    } catch (const std::exception& error) {
        std::printf("error: %s\n", error.what());
        return 2;
    }
    return 0;
}
