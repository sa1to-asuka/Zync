#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <string>
#include <unordered_map>
#include <vector>

namespace spektrafilm {

constexpr int kSpectralBands = 81;

struct Vec3 {
    float r = 0;
    float g = 0;
    float b = 0;
    float& operator[](int i) { return (&r)[i]; }
    float operator[](int i) const { return (&r)[i]; }
};

struct Image {
    int width = 0;
    int height = 0;
    std::vector<float> rgb;

    Image() = default;
    Image(int w, int h, float value = 0)
        : width(w), height(h), rgb(static_cast<size_t>(w) * h * 3, value) {}
    Vec3& at(int x, int y) {
        return *reinterpret_cast<Vec3*>(&rgb[(static_cast<size_t>(y) * width + x) * 3]);
    }
    const Vec3& at(int x, int y) const {
        return *reinterpret_cast<const Vec3*>(&rgb[(static_cast<size_t>(y) * width + x) * 3]);
    }
};

struct Lut3D {
    int size = 0;
    std::array<float, 3> minimum{0, 0, 0};
    std::array<float, 3> maximum{1, 1, 1};
    std::vector<float> data; // size^3 * 3

    void allocate(int n);
    float& at(int x, int y, int z, int c);
    Vec3 sample(const Vec3& value) const;
};

struct CurveModel {
    std::vector<std::vector<float>> centers;
    std::vector<std::vector<float>> amplitudes;
    std::vector<std::vector<float>> sigmas;
};

struct Profile {
    std::string id;
    std::string name;
    std::string type = "negative";
    std::string use = "still";
    std::string antihalation = "weak";
    std::string targetPrint;
    std::string referenceIlluminant = "D55";
    std::string viewingIlluminant = "D50";
    std::vector<float> logSensitivity; // 81 * 3, band major
    std::vector<float> sensitivityLinear; // 10^logSensitivity
    std::vector<float> rawLut; // 192 * 192 * 3 precomputed spectral integration
    std::vector<float> channelDensity; // 81 * 3, band major
    std::vector<float> baseDensity; // 81
    std::vector<float> logExposure;
    std::vector<float> densityCurves; // logExposure.size * 3
    std::vector<float> densityCurvesLayers; // logExposure.size * 3 * 3
    CurveModel curveModel;
    float proPhotoToXyz[9] = {1, 0, 0, 0, 1, 0, 0, 0, 1};

    Vec3 sensitivity(int band) const;
    Vec3 channelDensityAt(int band) const;
    Vec3 densityAt(int index) const;
};

struct Settings {
    std::string stockId = "kodak_portra_400";
    std::string paperId = "kodak_portra_endura";
    bool scanFilm = false;
    float exposureEv = 0;
    float halationAmount = 1;
    float halationSpatialScale = 1;
    float grainStrength = 1;
    float particleAreaUm2 = 0.2f;
    float yFilterShift = 0;
    float mFilterShift = 0;
    bool grain = true;
    bool dirCouplers = true;
    bool halation = true;
    bool autoExposure = false;
    bool preview = false;
    uint32_t seed = 42;
    // Physical pixel size for the whole image; 0 derives it from the frame.
    float pixelSizeUm = 0;
    // Offsets so tiled rendering keeps a continuous grain field.
    int grainOffsetX = 0;
    int grainOffsetY = 0;
    // Test/calibration overrides for the halation model.
    float halationStrengthOverride[3] = {-1.0f, -1.0f, -1.0f};
    float halationSigmaUmOverride = -1.0f;
    float halationScatterAmountOverride = -1.0f;
};

struct StockInfo {
    std::string id;
    std::string name;
    std::string targetPrint;
    std::string use;
};

class Engine {
public:
    explicit Engine(std::filesystem::path dataDirectory);

    std::vector<StockInfo> stocks() const;
    std::vector<StockInfo> papers() const;
    const Profile& profile(const std::string& id) const;

    // Input must be scene-linear ProPhoto RGB. Output is sRGB encoded [0, 1].
    Image render(const Image& linearProPhoto, const Settings& settings) const;

    Image exposeFilm(const Image& linearProPhoto, const Settings& settings,
                     const Profile& film) const;
    Image developFilm(const Image& logExposure, const Settings& settings,
                      const Profile& film) const;
    Image printDensity(const Image& filmDensity, const Settings& settings,
                       const Profile& film, const Profile& paper) const;
    Image scan(const Image& density, const Settings& settings,
               const Profile& source) const;

    Vec3 densityToXyz(const Vec3& density, const Profile& source) const;
    Vec3 filmToPrintLogExposure(const Vec3& density, const Profile& film,
                                const Profile& paper,
                                const std::vector<float>& illuminant) const;
    std::vector<float> enlargerIlluminant(float c, float m, float y) const;

    static float linearToSrgb(float value);
    Vec3 compressOutput(const Vec3& rgb) const;
    static Vec3 proPhotoToXyz(const Vec3& rgb);
    static Vec3 xyzToSrgb(const Vec3& xyz);
    static Vec3 srgbToLinear(const Vec3& rgb);
    static Vec3 srgbToProPhoto(const Vec3& rgb);

private:
    std::filesystem::path dataDirectory_;
    mutable std::unordered_map<std::string, Profile> profileCache_;
    std::vector<float> spectralLut_; // 192 * 192 * 81 float32
    std::vector<float> cmfs_; // 81 * 3
    std::vector<float> dichroics_; // 81 * 3
    std::vector<float> kg3_;
    std::vector<float> illuminants_[6];
    mutable std::unordered_map<std::string, Lut3D> printLuts_;
    mutable std::unordered_map<std::string, Lut3D> scanLuts_;
    std::vector<float> gamutLut_;
    int gamutSize_ = 0;
    float gamutMin_ = 0;
    float gamutMax_ = 2;
    bool gamutCubeRoot_ = false;
    mutable bool neutralFiltersLoaded_ = false;
    mutable std::unordered_map<std::string, std::array<float, 3>> neutralFilters_;

    void loadConstants();
    std::array<float, 3> neutralFilters(const std::string& filmId,
                                        const std::string& paperId) const;
    Vec3 illuminant(const std::string& name, int band) const;
    Vec3 customDichroic(int band) const;
    Vec3 spectralExposure(const Vec3& rgb, const Profile& film) const;
};

} // namespace spektrafilm
