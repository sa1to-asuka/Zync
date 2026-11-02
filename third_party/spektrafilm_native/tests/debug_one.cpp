#include "../include/spektrafilm/engine.hpp"
#include <cstdio>
#include <cstdlib>
#include <cmath>

int main(int argc, char** argv) {
    if (argc < 5) return 1;
    spektrafilm::Engine engine(argv[1]);
    spektrafilm::Settings s;
    s.stockId = argv[2];
    s.paperId = argv[3];
    s.grain = false;
    s.halation = false;
    s.dirCouplers = true;
    const float v = std::atof(argv[4]);
    spektrafilm::Image img(1,1);
    img.at(0,0) = {v,v,v};
    const auto le = engine.exposeFilm(img, s, engine.profile(s.stockId));
    const auto d = engine.developFilm(le, s, engine.profile(s.stockId));
    const auto pd = engine.printDensity(d, s, engine.profile(s.stockId), engine.profile(s.paperId));
    const auto xyz = engine.densityToXyz(pd.at(0,0), engine.profile(s.paperId));
    std::printf("xyz %g %g %g\n", xyz.r, xyz.g, xyz.b);
    const auto out = engine.scan(pd, s, engine.profile(s.paperId));
    std::printf("logE %g %g %g\nD %g %g %g\npD %g %g %g\nRGB %g %g %g\n",
        le.at(0,0).r, le.at(0,0).g, le.at(0,0).b,
        d.at(0,0).r, d.at(0,0).g, d.at(0,0).b,
        pd.at(0,0).r, pd.at(0,0).g, pd.at(0,0).b,
        out.at(0,0).r, out.at(0,0).g, out.at(0,0).b);
    return 0;
}
