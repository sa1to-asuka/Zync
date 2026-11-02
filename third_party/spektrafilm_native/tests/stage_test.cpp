#include "../include/spektrafilm/engine.hpp"

#include <cstdio>

int main(int argc, char** argv) {
    if (argc < 2) return 1;
    try {
        spektrafilm::Engine engine(argv[1]);
        spektrafilm::Settings settings;
        settings.stockId = argc > 2 ? argv[2] : "kodak_portra_400";
        settings.paperId = argc > 3 ? argv[3] : "kodak_portra_endura";
        settings.grain = false;
        settings.halation = false;
        settings.dirCouplers = true;

        const float values[] = {0.02f, 0.184f, 0.5f, 1.0f};
        for (float value : values) {
            spektrafilm::Image image(1, 1);
            image.at(0, 0) = {value, value, value};
            const auto exposed =
                engine.exposeFilm(image, settings, engine.profile(settings.stockId));
            const auto density =
                engine.developFilm(exposed, settings, engine.profile(settings.stockId));
            const auto print =
                engine.printDensity(density, settings, engine.profile(settings.stockId),
                                    engine.profile(settings.paperId));
            const auto scanned = engine.scan(print, settings, engine.profile(settings.paperId));
            const auto le = exposed.at(0, 0);
            const auto d = density.at(0, 0);
            const auto pd = print.at(0, 0);
            const auto rgb = scanned.at(0, 0);
            std::printf("%.3f | logE %.5f %.5f %.5f | D %.5f %.5f %.5f | pD %.5f %.5f %.5f | RGB %.5f %.5f %.5f\n",
                        value,
                        le.r, le.g, le.b,
                        d.r, d.g, d.b,
                        pd.r, pd.g, pd.b,
                        rgb.r, rgb.g, rgb.b);
        }
    } catch (const std::exception& error) {
        std::printf("error: %s\n", error.what());
    }
    return 0;
}
