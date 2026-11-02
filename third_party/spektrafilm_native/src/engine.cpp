#include "../include/spektrafilm/engine.hpp"
#include "../include/spektrafilm/math.hpp"
#include "data_io.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstring>
#include <fstream>
#include <random>

namespace spektrafilm {
namespace {

// ProPhoto RGB (D50) to XYZ. Smith & Guild primaries.
constexpr float kProPhotoToXyzD50[9] = {
    0.7976749f, 0.1351917f, 0.0313534f,
    0.2880402f, 0.7118741f, 0.0000857f,
    0.0000000f, 0.0000000f, 0.8252100f,
};
constexpr float kXyzD65ToSrgb[9] = {
    3.24096994f, -1.53738318f, -0.49861076f,
    -0.96924364f, 1.87596750f, 0.04155506f,
    0.05563008f, -0.20397696f, 1.05697151f,
};
constexpr float kCat16[9] = {
    0.401288f, 0.650173f, -0.051461f,
    -0.250268f, 1.204414f, 0.045854f,
    -0.002079f, 0.048952f, 0.953127f,
};
constexpr float kCat16Inverse[9] = {
    1.86206786f, -1.01125463f, 0.14919033f,
    0.38752654f, 0.62144744f, -0.00897398f,
    -0.01584150f, -0.03412294f, 1.04996444f,
};
constexpr float kBradford[9] = {
    0.8951f, 0.2664f, -0.1614f,
    -0.7502f, 1.7135f, 0.0367f,
    0.0389f, -0.0685f, 1.0296f,
};
constexpr float kBradfordInverse[9] = {
    0.9869929f, -0.1470543f, 0.1599627f,
    0.4323053f, 0.5183603f, 0.0492912f,
    -0.0085287f, 0.0400428f, 0.9684867f,
};
constexpr float kD50White[3] = {0.96422f, 1.0f, 0.82521f};
constexpr float kD65White[3] = {0.95047f, 1.0f, 1.08883f};

Vec3 multiply(const float* m, const Vec3& v) {
    return {
        m[0] * v.r + m[1] * v.g + m[2] * v.b,
        m[3] * v.r + m[4] * v.g + m[5] * v.b,
        m[6] * v.r + m[7] * v.g + m[8] * v.b,
    };
}
using Mat3 = std::array<float, 9>;
Mat3 toMat(const float* m) {
    return {m[0], m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8]};
}
Mat3 multiply(const Mat3& a, const Mat3& b) {
    Mat3 out{};
    for (int i = 0; i < 3; ++i)
        for (int j = 0; j < 3; ++j) {
            float sum = 0;
            for (int k = 0; k < 3; ++k) sum += a[i * 3 + k] * b[k * 3 + j];
            out[i * 3 + j] = sum;
        }
    return out;
}
Mat3 adaptation(const float* source, const float* dest, const float* coneMatrix,
                const float* inverse) {
    const Vec3 s = multiply(coneMatrix, {source[0], source[1], source[2]});
    const Vec3 d = multiply(coneMatrix, {dest[0], dest[1], dest[2]});
    const float scale[3] = {d.r / std::max(s.r, 1e-8f),
                            d.g / std::max(s.g, 1e-8f),
                            d.b / std::max(s.b, 1e-8f)};
    const Mat3 diag{scale[0], 0, 0, 0, scale[1], 0, 0, 0, scale[2]};
    const auto tmp = multiply(diag, toMat(coneMatrix));
    return multiply(toMat(inverse), tmp);
}
Mat3 cat16(const float* source, const float* dest) {
    return adaptation(source, dest, kCat16, kCat16Inverse);
}
Mat3 bradford(const float* source, const float* dest) {
    return adaptation(source, dest, kBradford, kBradfordInverse);
}

float mitchellWeight(float t) {
    const float x = std::fabs(t);
    constexpr float B = 1.0f / 3.0f;
    constexpr float C = 1.0f / 3.0f;
    if (x < 1.0f) {
        return (1.0f / 6.0f) * ((12 - 9 * B - 6 * C) * x * x * x
                              + (-18 + 12 * B + 6 * C) * x * x
                              + (6 - 2 * B));
    }
    if (x < 2.0f) {
        return (1.0f / 6.0f) * ((-B - 6 * C) * x * x * x
                              + (6 * B + 30 * C) * x * x
                              + (-12 * B - 48 * C) * x
                              + (8 * B + 24 * C));
    }
    return 0.0f;
}

Vec3 sampleRawLut(const std::vector<float>& lut, float x, float y) {
    const int baseX = static_cast<int>(std::floor(x));
    const int baseY = static_cast<int>(std::floor(y));
    const float fx = x - baseX;
    const float fy = y - baseY;
    Vec3 result;
    float total = 0;
    for (int j = -1; j <= 2; ++j) {
        const int yy = std::clamp(baseY + j, 0, 191);
        const float wy = mitchellWeight(j - fy);
        for (int i = -1; i <= 2; ++i) {
            const int xx = std::clamp(baseX + i, 0, 191);
            const float weight = mitchellWeight(i - fx) * wy;
            const size_t index = (static_cast<size_t>(xx) * 192 + yy) * 3;
            result.r += lut[index] * weight;
            result.g += lut[index + 1] * weight;
            result.b += lut[index + 2] * weight;
            total += weight;
        }
    }
    if (total > 1e-6f) {
        result.r /= total;
        result.g /= total;
        result.b /= total;
    }
    return result;
}

std::vector<float> readFloatFile(const std::filesystem::path& path) {
    std::ifstream input(path, std::ios::binary);
    if (!input) return {};
    input.seekg(0, std::ios::end);
    const auto bytes = static_cast<size_t>(input.tellg());
    input.seekg(0, std::ios::beg);
    std::vector<float> data(bytes / sizeof(float));
    input.read(reinterpret_cast<char*>(data.data()), static_cast<std::streamsize>(bytes));
    return data;
}

uint32_t hash32(uint32_t x) {
    x ^= x >> 16;
    x *= 0x7feb352du;
    x ^= x >> 15;
    x *= 0x846ca68bu;
    x ^= x >> 16;
    return x;
}
float uniform01(uint32_t seed) {
    return (hash32(seed) & 0xFFFFFFu) / 16777216.0f;
}
float normalRandom(uint32_t seed) {
    const float u1 = std::max(uniform01(seed), 1e-7f);
    const float u2 = uniform01(seed ^ 0x9e3779b9u);
    return std::sqrt(-2.0f * std::log(u1)) * std::cos(6.2831853f * u2);
}
int poissonRandom(float lambda, uint32_t seed) {
    if (lambda <= 0) return 0;
    if (lambda < 30.0f) {
        const float limit = std::exp(-lambda);
        float p = 1.0f;
        int k = 0;
        do {
            ++k;
            p *= uniform01(seed + static_cast<uint32_t>(k) * 0x9e3779b9u);
        } while (p > limit && k < 1024);
        return k - 1;
    }
    return std::max(0, static_cast<int>(std::lround(lambda + std::sqrt(lambda) * normalRandom(seed))));
}
int binomialRandom(int n, float p, uint32_t seed) {
    if (n <= 0 || p <= 0) return 0;
    if (p >= 1) return n;
    if (n < 25) {
        int count = 0;
        for (int k = 0; k < n; ++k) {
            if (uniform01(seed + static_cast<uint32_t>(k) * 0x85ebca6bu) < p) ++count;
        }
        return count;
    }
    const float mean = n * p;
    const float variance = n * p * (1 - p);
    if (variance > 10.0f) {
        return std::clamp(static_cast<int>(std::lround(mean + std::sqrt(variance) * normalRandom(seed))), 0, n);
    }
    float u = uniform01(seed);
    float cdf = 0;
    float prob = std::pow(1 - p, static_cast<float>(n));
    int k = 0;
    while (cdf < u && k <= n) {
        cdf += prob;
        if (k < n) prob *= (static_cast<float>(n - k) / (k + 1)) * (p / (1 - p));
        ++k;
    }
    return std::max(0, k - 1);
}

Vec3 interpCurves(const Vec3& logExposure, const std::vector<float>& x,
                  const std::vector<float>& curves, float gamma = 1.0f) {
    Vec3 out;
    const size_t n = x.size();
    for (int c = 0; c < 3; ++c) {
        const float target = logExposure[c] / gamma;
        if (target <= x.front()) { out[c] = curves[c]; continue; }
        if (target >= x.back()) { out[c] = curves[(n - 1) * 3 + c]; continue; }
        size_t lo = 0, hi = n - 1;
        while (hi - lo > 1) {
            const size_t mid = (lo + hi) / 2;
            if (x[mid] <= target) lo = mid; else hi = mid;
        }
        const float span = x[hi] - x[lo];
        const float t = span > 1e-8f ? (target - x[lo]) / span : 0.0f;
        out[c] = curves[lo * 3 + c] * (1 - t) + curves[hi * 3 + c] * t;
    }
    return out;
}

std::vector<float> normalizedCurves(const Profile& profile) {
    std::vector<float> curves = profile.densityCurves;
    const size_t n = profile.logExposure.size();
    for (int c = 0; c < 3; ++c) {
        float minimum = curves[c];
        for (size_t i = 0; i < n; ++i) minimum = std::min(minimum, curves[i * 3 + c]);
        for (size_t i = 0; i < n; ++i) curves[i * 3 + c] -= minimum;
    }
    return curves;
}

std::array<float, 9> couplerMatrix(const Profile& film) {
    std::array<float, 9> m{};
    const bool positive = film.type == "positive";
    float same[3], rTo[2], gTo[2], bTo[2];
    if (positive) {
        same[0] = 0.12f; same[1] = 0.08f; same[2] = 0.06f;
        rTo[0] = 0.12f; rTo[1] = 0.06f;
        gTo[0] = 0.08f; gTo[1] = 0.06f;
        bTo[0] = 0.06f; bTo[1] = 0.06f;
    } else {
        same[0] = 0.336f; same[1] = 0.319f; same[2] = 0.273f;
        rTo[0] = 0.353f; rTo[1] = 0.302f;
        gTo[0] = 0.154f; gTo[1] = 0.353f;
        bTo[0] = 0.168f; bTo[1] = 0.226f;
    }
    if (film.id == "fujifilm_velvia_100") {
        same[0] = 0.108f; same[1] = 0.072f; same[2] = 0.054f;
        rTo[0] = 0.108f; rTo[1] = 0.054f;
        gTo[0] = 0.072f; gTo[1] = 0.054f;
        bTo[0] = 0.054f; bTo[1] = 0.054f;
    } else if (film.id == "fujifilm_provia_100f") {
        same[0] = 0.156f; same[1] = 0.104f; same[2] = 0.078f;
        rTo[0] = 0.156f; rTo[1] = 0.078f;
        gTo[0] = 0.104f; gTo[1] = 0.078f;
        bTo[0] = 0.078f; bTo[1] = 0.078f;
    }
    m[0] = same[0]; m[4] = same[1]; m[8] = same[2];
    m[1] = rTo[0]; m[2] = rTo[1];
    m[3] = gTo[0]; m[5] = gTo[1];
    m[6] = bTo[0]; m[7] = bTo[1];
    return m;
}

std::vector<float> curvesBeforeCouplers(const Profile& film,
                                        const std::vector<float>& curves,
                                        const std::array<float, 9>& matrix) {
    const bool positive = film.type == "positive";
    const size_t n = film.logExposure.size();
    std::vector<float> maxDensity(3, 0.0f);
    for (size_t i = 0; i < n; ++i)
        for (int c = 0; c < 3; ++c) maxDensity[c] = std::max(maxDensity[c], curves[i * 3 + c]);

    std::vector<float> silver = curves;
    if (positive) {
        for (size_t i = 0; i < n; ++i)
            for (int c = 0; c < 3; ++c) silver[i * 3 + c] = maxDensity[c] - curves[i * 3 + c];
    }
    std::vector<float> corrected(curves.size());
    std::vector<float> exposure0(n);
    for (int c = 0; c < 3; ++c) {
        for (size_t i = 0; i < n; ++i) {
            float amount = 0;
            for (int k = 0; k < 3; ++k) amount += silver[i * 3 + k] * matrix[k * 3 + c];
            exposure0[i] = film.logExposure[i] - amount;
        }
        for (size_t i = 0; i < n; ++i) {
            const float x = film.logExposure[i];
            if (x <= exposure0.front()) corrected[i * 3 + c] = curves[c];
            else if (x >= exposure0.back()) corrected[i * 3 + c] = curves[(n - 1) * 3 + c];
            else {
                size_t lo = 0, hi = n - 1;
                while (hi - lo > 1) {
                    const size_t mid = (lo + hi) / 2;
                    if (exposure0[mid] <= x) lo = mid; else hi = mid;
                }
                const float span = exposure0[hi] - exposure0[lo];
                const float t = span > 1e-8f ? (x - exposure0[lo]) / span : 0.0f;
                corrected[i * 3 + c] = curves[lo * 3 + c] * (1 - t) + curves[hi * 3 + c] * t;
            }
        }
    }
    return corrected;
}

void applyHalation(Image& raw, const Profile& film, const Settings& settings,
                   float pixelSizeUm) {
    if (!settings.halation || settings.halationAmount <= 0) return;
    const bool cine = film.use == "cine";
    float strength[3];
    if (film.antihalation == "strong") { strength[0] = 0.015f; strength[1] = 0.005f; strength[2] = 0.0f; }
    else if (film.antihalation == "no") { strength[0] = 0.30f; strength[1] = 0.10f; strength[2] = 0.015f; }
    else { strength[0] = 0.08f; strength[1] = 0.02f; strength[2] = 0.0f; }
    for (int c = 0; c < 3; ++c) {
        if (settings.halationStrengthOverride[c] >= 0) {
            strength[c] = settings.halationStrengthOverride[c];
        }
    }
    const float sigmaBase = settings.halationSigmaUmOverride > 0
        ? settings.halationSigmaUmOverride
        : (cine ? 50.0f : 65.0f);
    const float sigmaH = sigmaBase * settings.halationSpatialScale / pixelSizeUm;
    const float sigmaCore[3] = {2.2f, 2.0f, 1.6f};
    const float lambdaTail[3] = {9.3f, 9.7f, 9.1f};
    const float tailWeight[3] = {0.78f, 0.65f, 0.67f};
    const float scatter = settings.halationScatterAmountOverride >= 0
        ? settings.halationScatterAmountOverride
        : 1.0f;
    constexpr float decay = 0.5f;

    for (int c = 0; c < 3; ++c) {
        std::vector<float> plane(static_cast<size_t>(raw.width) * raw.height);
        for (size_t i = 0; i < plane.size(); ++i) plane[i] = raw.rgb[i * 3 + c];
        std::vector<float> core = plane;
        std::vector<float> tail = plane;
        blurPlane(core, raw.width, raw.height, sigmaCore[c] / pixelSizeUm);
        exponentialPlane(tail, raw.width, raw.height, lambdaTail[c] / pixelSizeUm);
        for (size_t i = 0; i < plane.size(); ++i) {
            const float scattered = (1 - tailWeight[c]) * core[i] + tailWeight[c] * tail[i];
            plane[i] = (1 - scatter) * plane[i] + scatter * scattered;
        }
        const float amount = strength[c] * settings.halationAmount;
        if (amount > 0 && sigmaH > 0) {
            int bounces = 3;
            float weights[3];
            float total = 0;
            for (int k = 0; k < bounces; ++k) { weights[k] = std::pow(decay, static_cast<float>(k)); total += weights[k]; }
            std::vector<float> halo(plane.size(), 0.0f);
            for (int k = 1; k <= bounces; ++k) {
                std::vector<float> component = plane;
                blurPlane(component, raw.width, raw.height, sigmaH * std::sqrt(static_cast<float>(k)));
                const float weight = weights[k - 1] / total;
                for (size_t i = 0; i < halo.size(); ++i) halo[i] += weight * component[i];
            }
            for (size_t i = 0; i < plane.size(); ++i) {
                plane[i] = (plane[i] + amount * halo[i]) / (1 + amount);
            }
        }
        for (size_t i = 0; i < plane.size(); ++i) raw.rgb[i * 3 + c] = plane[i];
    }
}

void applyGrain(Image& density, const Profile& film, const Settings& settings,
                float pixelSizeUm, const std::vector<float>& curves) {
    if (!settings.grain || settings.grainStrength <= 0) return;
    const size_t n = film.logExposure.size();
    float densityMax[3] = {0, 0, 0};
    for (size_t i = 0; i < n; ++i)
        for (int c = 0; c < 3; ++c) densityMax[c] = std::max(densityMax[c], curves[i * 3 + c]);
    const float densityMin[3] = {0.03f, 0.03f, 0.03f};
    const float particleScale[3] = {1.6f, 1.6f, 3.2f};
    const float uniformity[3] = {0.97f, 0.99f, 0.97f};
    const float pixelArea = pixelSizeUm * pixelSizeUm;
    float particles[3];
    for (int c = 0; c < 3; ++c) {
        particles[c] = pixelArea / std::max(settings.particleAreaUm2 * particleScale[c], 1e-4f);
    }
    const float odParticle[3] = {
        (densityMax[0] + densityMin[0]) / std::max(particles[0], 1.0f),
        (densityMax[1] + densityMin[1]) / std::max(particles[1], 1.0f),
        (densityMax[2] + densityMin[2]) / std::max(particles[2], 1.0f),
    };
    parallelFor(density.height, [&](int y) {
        for (int x = 0; x < density.width; ++x) {
            Vec3& d = density.at(x, y);
            for (int c = 0; c < 3; ++c) {
                const float maxTotal = densityMax[c] + densityMin[c];
                const float probability = std::clamp((d[c] + densityMin[c]) / std::max(maxTotal, 1e-5f), 1e-6f, 1.0f - 1e-6f);
                const float saturation = 1.0f - probability * uniformity[c] * (1.0f - 1e-6f);
                const int gx = x + settings.grainOffsetX;
                const int gy = y + settings.grainOffsetY;
                const uint32_t seed = settings.seed
                    ^ static_cast<uint32_t>(gx * 73856093)
                    ^ static_cast<uint32_t>(gy * 19349663)
                    ^ static_cast<uint32_t>(c * 83492791);
                const int seeds = poissonRandom(particles[c] / std::max(saturation, 1e-6f), seed);
                const int developed = binomialRandom(seeds, probability, seed ^ 0x5bd1e995u);
                const float grain = static_cast<float>(developed) * odParticle[c] * saturation;
                const float value = grain - densityMin[c];
                d[c] += (value - d[c]) * settings.grainStrength;
            }
        }
    });
    for (int c = 0; c < 3; ++c) {
        std::vector<float> plane(static_cast<size_t>(density.width) * density.height);
        for (size_t i = 0; i < plane.size(); ++i) plane[i] = density.rgb[i * 3 + c];
        blurPlane(plane, density.width, density.height, 0.65f);
        for (size_t i = 0; i < plane.size(); ++i) density.rgb[i * 3 + c] = plane[i];
    }
}

Vec3 compressGamut(Vec3 rgb) {
    const float luminance = 0.2126f * rgb.r + 0.7152f * rgb.g + 0.0722f * rgb.b;
    for (int c = 0; c < 3; ++c) {
        if (rgb[c] < 0) rgb[c] = std::max(0.0f, luminance + (rgb[c] - luminance) * 0.2f);
    }
    // One-sided perceptual highlight roll-off (approximates the upstream
    // CAM16-UCS lightness compression with the same 0.7 / 1.0 / 2.2 knee).
    const float luma = std::max(0.2126f * rgb.r + 0.7152f * rgb.g + 0.0722f * rgb.b, 0.0f);
    constexpr float kKneeThreshold = 0.7f * 0.7f * 0.7f; // 0.7 in cube-root space
    if (luma > kKneeThreshold) {
        const float lightness = std::cbrt(luma);
        const float n = std::max((lightness - 0.7f) / 0.3f, 0.0f);
        const float compressed = 0.7f
            + 0.3f * n / std::pow(1.0f + std::pow(n, 2.2f), 1.0f / 2.2f);
        const float scale = std::pow(compressed, 3.0f) / std::max(luma, 1e-6f);
        rgb.r *= scale;
        rgb.g *= scale;
        rgb.b *= scale;
    }
    return rgb;
}

} // namespace

void Lut3D::allocate(int n) {
    size = n;
    data.assign(static_cast<size_t>(n) * n * n * 3, 0.0f);
}
float& Lut3D::at(int x, int y, int z, int c) {
    return data[((static_cast<size_t>(x) * size + y) * size + z) * 3 + c];
}
Vec3 Lut3D::sample(const Vec3& value) const {
    if (size < 2) return value;
    float coordinate[3];
    for (int c = 0; c < 3; ++c) {
        const float range = maximum[c] - minimum[c];
        coordinate[c] = range > 1e-8f
            ? std::clamp((value[c] - minimum[c]) / range, 0.0f, 1.0f)
            : 0.0f;
        coordinate[c] *= size - 1;
    }
    const int x0 = static_cast<int>(coordinate[0]);
    const int y0 = static_cast<int>(coordinate[1]);
    const int z0 = static_cast<int>(coordinate[2]);
    const int x1 = std::min(x0 + 1, size - 1);
    const int y1 = std::min(y0 + 1, size - 1);
    const int z1 = std::min(z0 + 1, size - 1);
    const float fx = coordinate[0] - x0;
    const float fy = coordinate[1] - y0;
    const float fz = coordinate[2] - z0;
    Vec3 result;
    for (int c = 0; c < 3; ++c) {
        auto valueAt = [&](int x, int y, int z) {
            return data[((static_cast<size_t>(x) * size + y) * size + z) * 3 + c];
        };
        const float c00 = valueAt(x0, y0, z0) * (1 - fx) + valueAt(x1, y0, z0) * fx;
        const float c10 = valueAt(x0, y1, z0) * (1 - fx) + valueAt(x1, y1, z0) * fx;
        const float c01 = valueAt(x0, y0, z1) * (1 - fx) + valueAt(x1, y0, z1) * fx;
        const float c11 = valueAt(x0, y1, z1) * (1 - fx) + valueAt(x1, y1, z1) * fx;
        const float c0 = c00 * (1 - fy) + c10 * fy;
        const float c1 = c01 * (1 - fy) + c11 * fy;
        result[c] = c0 * (1 - fz) + c1 * fz;
    }
    return result;
}

float Engine::linearToSrgb(float value) {
    value = std::clamp(value, 0.0f, 1.0f);
    return value <= 0.0031308f ? value * 12.92f
        : 1.055f * std::pow(value, 1.0f / 2.4f) - 0.055f;
}
Vec3 Engine::proPhotoToXyz(const Vec3& rgb) { return multiply(kProPhotoToXyzD50, rgb); }
Vec3 Engine::xyzToSrgb(const Vec3& xyz) { return multiply(kXyzD65ToSrgb, xyz); }
Vec3 Engine::srgbToLinear(const Vec3& rgb) {
    Vec3 result;
    for (int c = 0; c < 3; ++c) {
        const float value = rgb[c];
        result[c] = value <= 0.04045f ? value / 12.92f
            : std::pow((value + 0.055f) / 1.055f, 2.4f);
    }
    return result;
}

Vec3 Engine::srgbToProPhoto(const Vec3& rgb) {
    // sRGB (D65) -> linear -> XYZ -> Bradford D50 -> linear ProPhoto.
    static const float kSrgbToXyz[9] = {
        0.4123908f, 0.3575843f, 0.1804808f,
        0.2126390f, 0.7151687f, 0.0721923f,
        0.0193308f, 0.1191948f, 0.9505322f,
    };
    static const float kXyzD50ToProPhoto[9] = {
        1.3459434f, -0.2556075f, -0.0511118f,
        -0.5445988f, 1.5081673f, 0.0205351f,
        0.0f, 0.0f, 1.2118128f,
    };
    const Vec3 linear = srgbToLinear(rgb);
    const Vec3 xyz65 = multiply(kSrgbToXyz, linear);
    const auto adapt = bradford(kD65White, kD50White);
    return multiply(kXyzD50ToProPhoto, multiply(adapt.data(), xyz65));
}

Engine::Engine(std::filesystem::path dataDirectory)
    : dataDirectory_(std::move(dataDirectory)) {
    spectralLut_ = readNpyFloat32(
        dataDirectory_ / "irradiance_xy_tc.npy");
    if (spectralLut_.size() != 192u * 192u * 81u) {
        throw std::runtime_error("Spectral LUT has unexpected dimensions");
    }
    loadConstants();
}

void Engine::loadConstants() {
    const auto root = parseJson(readText(dataDirectory_ / "spectral_constants.json"));
    cmfs_ = jsonFloatMatrix(root["cmfs"]).empty() ? std::vector<float>() : std::vector<float>();
    for (const auto& row : jsonFloatMatrix(root["cmfs"]))
        for (float value : row) cmfs_.push_back(value);
    dichroics_.clear();
    for (const auto& row : jsonFloatMatrix(root["dichroics"]))
        for (float value : row) dichroics_.push_back(value);
    kg3_ = jsonFloats(root["kg3"]);
    const auto& sources = root["illuminants"];
    const char* names[] = {"D50", "D55", "D65", "T", "K75P", "TH-KG3"};
    for (int i = 0; i < 6; ++i) illuminants_[i] = jsonFloats(sources[names[i]]);

    const auto gamutPath = dataDirectory_ / "output_gamut_srgb.bin";
    const auto gamutHeader = dataDirectory_ / "output_gamut_srgb.json";
    if (std::filesystem::exists(gamutPath) && std::filesystem::exists(gamutHeader)) {
        const auto header = parseJson(readText(gamutHeader));
        gamutSize_ = static_cast<int>(header["size"].asNumber(41));
        gamutMin_ = static_cast<float>(header["min"].asNumber(0.0));
        gamutMax_ = static_cast<float>(header["max"].asNumber(2.0));
        gamutCubeRoot_ = header.has("mapping") && header["mapping"].asString() == "cbrt";
        gamutLut_ = readFloatFile(gamutPath);
        if (gamutLut_.size() != static_cast<size_t>(gamutSize_) * gamutSize_ * gamutSize_ * 3u) {
            gamutLut_.clear();
            gamutSize_ = 0;
        }
    }
}

Vec3 Engine::illuminant(const std::string& name, int band) const {
    const char* names[] = {"D50", "D55", "D65", "T", "K75P", "TH-KG3"};
    for (int i = 0; i < 6; ++i) {
        if (name == names[i]) {
            const float value = illuminants_[i][band];
            return {value, value, value};
        }
    }
    throw std::runtime_error("Unsupported illuminant: " + name);
}

Vec3 Engine::customDichroic(int band) const {
    const size_t i = static_cast<size_t>(band) * 3;
    return {dichroics_[i], dichroics_[i + 1], dichroics_[i + 2]};
}

std::vector<StockInfo> Engine::stocks() const {
    std::vector<StockInfo> result;
    for (const auto& entry : std::filesystem::directory_iterator(dataDirectory_ / "profiles")) {
        if (entry.path().extension() != ".json") continue;
        const auto root = parseJson(readText(entry.path()));
        const auto& info = root["info"];
        if (info["support"].asString() != "film" || info["stage"].asString() != "filming") continue;
        result.push_back({info["stock"].asString(), info["name"].asString(),
                          info["target_print"].asString(), info["use"].asString()});
    }
    std::sort(result.begin(), result.end(), [](const auto& a, const auto& b) { return a.name < b.name; });
    return result;
}

std::vector<StockInfo> Engine::papers() const {
    std::vector<StockInfo> result;
    for (const auto& entry : std::filesystem::directory_iterator(dataDirectory_ / "profiles")) {
        if (entry.path().extension() != ".json") continue;
        const auto root = parseJson(readText(entry.path()));
        const auto& info = root["info"];
        if (info["stage"].asString() != "printing") continue;
        result.push_back({info["stock"].asString(), info["name"].asString(), "", info["use"].asString()});
    }
    std::sort(result.begin(), result.end(), [](const auto& a, const auto& b) { return a.name < b.name; });
    return result;
}

const Profile& Engine::profile(const std::string& id) const {
    auto it = profileCache_.find(id);
    if (it != profileCache_.end()) return it->second;

    const auto root = parseJson(readText(dataDirectory_ / "profiles" / (id + ".json")));
    const auto& info = root["info"];
    const auto& data = root["data"];
    Profile p;
    p.id = info["stock"].asString(id);
    p.name = info["name"].asString(id);
    p.type = info["type"].asString("negative");
    p.use = info["use"].asString("still");
    p.antihalation = info["antihalation"].asString("weak");
    p.targetPrint = info["target_print"].asString();
    p.referenceIlluminant = info["reference_illuminant"].asString("D55");
    p.viewingIlluminant = info["viewing_illuminant"].asString("D50");
    for (const auto& row : jsonFloatMatrix(data["log_sensitivity"]))
        for (float value : row) p.logSensitivity.push_back(value);
    for (const auto& row : jsonFloatMatrix(data["channel_density"]))
        for (float value : row) p.channelDensity.push_back(value);
    p.baseDensity = jsonFloats(data["base_density"]);
    p.logExposure = jsonFloats(data["log_exposure"]);
    for (const auto& row : jsonFloatMatrix(data["density_curves"]))
        for (float value : row) p.densityCurves.push_back(value);
    for (const auto& slice : data["density_curves_layers"].array)
        for (const auto& row : slice.array)
            for (const auto& value : row.array) p.densityCurvesLayers.push_back(static_cast<float>(value.number));
    const auto& model = data["density_curves_model"];
    p.curveModel.centers = jsonFloatMatrix(model["centers"]);
    p.curveModel.amplitudes = jsonFloatMatrix(model["amplitudes"]);
    p.curveModel.sigmas = jsonFloatMatrix(model["sigmas"]);
    if (p.logSensitivity.size() != 81u * 3u || p.channelDensity.size() != 81u * 3u ||
        p.baseDensity.size() != 81u || p.densityCurves.size() != p.logExposure.size() * 3u) {
        throw std::runtime_error("Invalid profile dimensions: " + id);
    }

    p.sensitivityLinear.resize(p.logSensitivity.size());
    for (size_t i = 0; i < p.logSensitivity.size(); ++i)
        p.sensitivityLinear[i] = std::isfinite(p.logSensitivity[i])
            ? std::pow(10.0f, p.logSensitivity[i]) : 0.0f;

    // Hanatos 2025 spectral window, normalized so the reference illuminant
    // keeps its midgray response (same as compute_hanatos2025_tc_lut).
    std::vector<float> effective = p.sensitivityLinear;
    const auto windowParams = jsonFloats(data["hanatos2025_adaptation_window_params"]);
    if (windowParams.size() >= 4) {
        const float cuv = windowParams[0], suv = std::max(windowParams[1], 1e-3f);
        const float cir = windowParams[2], sir = std::max(windowParams[3], 1e-3f);
        std::vector<float> window(81);
        for (int band = 0; band < 81; ++band) {
            const float wavelength = 380.0f + 5.0f * band;
            const float uv = 0.5f * (1.0f + erfApprox((wavelength - cuv) / (suv * 1.41421356f)));
            const float ir = 0.5f * (1.0f - erfApprox((wavelength - cir) / (sir * 1.41421356f)));
            window[band] = uv * ir;
        }
        for (int c = 0; c < 3; ++c) {
            float numerator = 0, denominator = 0;
            for (int band = 0; band < 81; ++band) {
                const float illum = illuminant(p.referenceIlluminant, band).r;
                const float sensitivity = p.sensitivityLinear[band * 3 + c];
                numerator += sensitivity * window[band] * illum;
                denominator += sensitivity * illum;
            }
            const float scale = denominator / std::max(numerator, 1e-12f);
            for (int band = 0; band < 81; ++band)
                effective[band * 3 + c] = p.sensitivityLinear[band * 3 + c] * window[band] * scale;
        }
    }

    const auto baked = dataDirectory_ / "raw_luts" / (id + ".bin");
    if (std::filesystem::exists(baked)) {
        p.rawLut = readFloatFile(baked);
        if (p.rawLut.size() != 192u * 192u * 3u) p.rawLut.clear();
    }
    if (p.rawLut.empty()) {
    p.rawLut.assign(192u * 192u * 3u, 0.0f);
    for (int y = 0; y < 192; ++y) {
        for (int x = 0; x < 192; ++x) {
            const size_t base = (static_cast<size_t>(x) * 192 + y);
            float r = 0, g = 0, b = 0;
            for (int band = 0; band < 81; ++band) {
                const float spectrum = spectralLut_[base * 81 + band];
                r += spectrum * effective[band * 3];
                g += spectrum * effective[band * 3 + 1];
                b += spectrum * effective[band * 3 + 2];
            }
            p.rawLut[base * 3] = r;
            p.rawLut[base * 3 + 1] = g;
            p.rawLut[base * 3 + 2] = b;
        }
    }
    }

    Vec3 white{0, 0, 0};
    for (int band = 0; band < 81; ++band) {
        const float value = illuminant(p.referenceIlluminant, band).r;
        white.r += value * cmfs_[band * 3];
        white.g += value * cmfs_[band * 3 + 1];
        white.b += value * cmfs_[band * 3 + 2];
    }
    const float whiteY = std::max(white.g, 1e-8f);
    const float whiteArray[3] = {white.r / whiteY, 1.0f, white.b / whiteY};
    const auto adapted = multiply(cat16(kD50White, whiteArray), toMat(kProPhotoToXyzD50));
    std::memcpy(p.proPhotoToXyz, adapted.data(), sizeof(p.proPhotoToXyz));

    return profileCache_.emplace(id, std::move(p)).first->second;
}

Vec3 Engine::spectralExposure(const Vec3& rgb, const Profile& film) const {
    const Vec3 xyz = multiply(film.proPhotoToXyz, rgb);
    const float brightness = std::max(xyz.r + xyz.g + xyz.b, 1e-12f);
    const float chromaX = std::clamp(xyz.r / brightness, 0.0f, 0.999999f);
    const float chromaY = std::max(xyz.g / brightness, 0.0f);
    // Upstream _tri2quad maps chromaticity (x, y) onto the LUT square.
    const float squareX = (1.0f - chromaX) * (1.0f - chromaX);
    const float squareY = chromaY / std::max(1.0f - chromaX, 1e-10f);
    const float x = std::clamp(squareX, 0.0f, 1.0f) * 191.0f;
    const float y = std::clamp(squareY, 0.0f, 1.0f) * 191.0f;
    const Vec3 raw = sampleRawLut(film.rawLut, x, y);
    return {raw.r * brightness, raw.g * brightness, raw.b * brightness};
}

Image Engine::exposeFilm(const Image& input, const Settings& settings, const Profile& film) const {
    Image logExposure(input.width, input.height);
    const float gain = std::pow(2.0f, settings.exposureEv);
    parallelFor(input.height, [&](int y) {
        for (int x = 0; x < input.width; ++x) {
            Vec3 raw = spectralExposure(input.at(x, y), film);
            raw.r *= gain; raw.g *= gain; raw.b *= gain;
            logExposure.at(x, y) = raw;
        }
    });
    const float pixelSizeUm = settings.pixelSizeUm > 0
        ? settings.pixelSizeUm
        : 35000.0f / static_cast<float>(std::max(input.width, input.height));
    applyHalation(logExposure, film, settings, pixelSizeUm);
    for (float& value : logExposure.rgb)
        value = std::log10(std::max(value, 1e-10f));
    return logExposure;
}

Image Engine::developFilm(const Image& logExposure, const Settings& settings,
                          const Profile& film) const {
    const auto curves = normalizedCurves(film);
    Image density(logExposure.width, logExposure.height);
    parallelFor(logExposure.height, [&](int y) {
        for (int x = 0; x < logExposure.width; ++x) {
            density.at(x, y) =
                interpCurves(logExposure.at(x, y), film.logExposure, curves);
        }
    });

    if (settings.dirCouplers) {
        const auto matrix = couplerMatrix(film);
        const size_t n = film.logExposure.size();
        float maxDensity[3] = {0, 0, 0};
        for (size_t i = 0; i < n; ++i)
            for (int c = 0; c < 3; ++c) maxDensity[c] = std::max(maxDensity[c], curves[i * 3 + c]);

        Image correction(density.width, density.height);
        parallelFor(density.height, [&](int y) {
            for (int x = 0; x < density.width; ++x) {
                const Vec3 d = density.at(x, y);
                Vec3 silver = d;
                if (film.type == "positive") {
                    silver = {maxDensity[0] - d.r, maxDensity[1] - d.g, maxDensity[2] - d.b};
                }
                Vec3 value;
                for (int m = 0; m < 3; ++m)
                    value[m] = silver.r * matrix[m] + silver.g * matrix[3 + m] + silver.b * matrix[6 + m];
                correction.at(x, y) = value;
            }
        });
        const float pixelSizeUm = settings.pixelSizeUm > 0
            ? settings.pixelSizeUm
            : 35000.0f / static_cast<float>(std::max(density.width, density.height));
        const float sigma = 20.0f / pixelSizeUm;
        const float tail = 200.0f / pixelSizeUm;
        for (int c = 0; c < 3; ++c) {
            std::vector<float> plane(static_cast<size_t>(density.width) * density.height);
            for (size_t i = 0; i < plane.size(); ++i) plane[i] = correction.rgb[i * 3 + c];
            std::vector<float> gauss = plane;
            std::vector<float> exponentialTail = plane;
            blurPlane(gauss, density.width, density.height, sigma);
            exponentialPlane(exponentialTail, density.width, density.height, tail);
            for (size_t i = 0; i < plane.size(); ++i)
                correction.rgb[i * 3 + c] = 0.94f * gauss[i] + 0.06f * exponentialTail[i];
        }

        const auto before = curvesBeforeCouplers(film, curves, matrix);
        parallelFor(density.height, [&](int y) {
            for (int x = 0; x < density.width; ++x) {
                const Vec3 correctedLog{
                    logExposure.at(x, y).r - correction.at(x, y).r,
                    logExposure.at(x, y).g - correction.at(x, y).g,
                    logExposure.at(x, y).b - correction.at(x, y).b,
                };
                density.at(x, y) = interpCurves(correctedLog, film.logExposure, before);
            }
        });
    }

    const float pixelSizeUm = settings.pixelSizeUm > 0
        ? settings.pixelSizeUm
        : 35000.0f / static_cast<float>(std::max(density.width, density.height));
    applyGrain(density, film, settings, pixelSizeUm, curves);
    return density;
}

Vec3 Engine::filmToPrintLogExposure(const Vec3& density, const Profile& film,
                                    const Profile& paper,
                                    const std::vector<float>& illum) const {
    Vec3 raw{0, 0, 0};
    for (int band = 0; band < 81; ++band) {
        const size_t i = static_cast<size_t>(band) * 3;
        const float densitySpectral =
            film.channelDensity[i] * density.r +
            film.channelDensity[i + 1] * density.g +
            film.channelDensity[i + 2] * density.b +
            film.baseDensity[band];
        if (!std::isfinite(densitySpectral)) continue;
        const float light = std::pow(10.0f, -densitySpectral) * illum[band];
        raw.r += light * paper.sensitivityLinear[i];
        raw.g += light * paper.sensitivityLinear[i + 1];
        raw.b += light * paper.sensitivityLinear[i + 2];
    }
    for (int c = 0; c < 3; ++c) raw[c] = std::log10(std::max(raw[c], 1e-10f));
    return raw;
}

std::array<float, 3> Engine::neutralFilters(const std::string& filmId,
                                           const std::string& paperId) const {
    if (!neutralFiltersLoaded_) {
        neutralFiltersLoaded_ = true;
        try {
            const auto root = parseJson(
                readText(dataDirectory_ / "neutral_print_filters.json"));
            for (const auto& [paper, illuminants] : root.object) {
                const Json* source = nullptr;
                for (const auto& [name, value] : illuminants.object) {
                    if (name == "TH-KG3") source = &value;
                }
                if (source == nullptr) continue;
                for (const auto& [film, values] : source->object) {
                    if (values.size() >= 3) {
                        neutralFilters_[paper + "|" + film] = {
                            static_cast<float>(values.at(0).number),
                            static_cast<float>(values.at(1).number),
                            static_cast<float>(values.at(2).number)};
                    }
                }
            }
        } catch (...) {
        }
    }
    const auto it = neutralFilters_.find(paperId + "|" + filmId);
    if (it != neutralFilters_.end()) return it->second;
    return {0.0f, 65.0f, 55.0f};
}

std::vector<float> Engine::enlargerIlluminant(float c, float m, float y) const {
    std::vector<float> result(81);
    const float values[3] = {c, m, y};
    float transmittance[3];
    for (int i = 0; i < 3; ++i) transmittance[i] = std::pow(10.0f, -values[i] / 100.0f);
    for (int band = 0; band < 81; ++band) {
        const Vec3 filter = customDichroic(band);
        float total = 1.0f;
        for (int i = 0; i < 3; ++i) {
            const float dimmed = 1.0f - (1.0f - filter[i]) * (1.0f - transmittance[i]);
            total *= dimmed;
        }
        result[band] = illuminant("TH-KG3", band).r * total;
    }
    return result;
}

Image Engine::printDensity(const Image& filmDensity, const Settings& settings,
                           const Profile& film, const Profile& paper) const {
    Vec3 minimum{-0.03f, -0.03f, -0.03f};
    Vec3 maximum{0.1f, 0.1f, 0.1f};
    const size_t curveCount = film.logExposure.size();
    for (size_t i = 0; i < curveCount; ++i) {
        for (int c = 0; c < 3; ++c) {
            const float value = film.densityCurves[i * 3 + c];
            if (!std::isfinite(value)) continue;
            maximum[c] = std::max(maximum[c], value);
        }
    }

    const auto neutral = neutralFilters(film.id, paper.id);
    const float filter[3] = {neutral[0],
                             neutral[1] + settings.mFilterShift,
                             neutral[2] + settings.yFilterShift};
    const auto illum = enlargerIlluminant(filter[0], filter[1], filter[2]);

    // Midgray normalization keeps the print neutral at 18% gray.
    const Vec3 gray{0.184f, 0.184f, 0.184f};
    const Vec3 grayRaw = spectralExposure(gray, film);
    const Vec3 grayLog{std::log10(std::max(grayRaw.r, 1e-10f)),
                       std::log10(std::max(grayRaw.g, 1e-10f)),
                       std::log10(std::max(grayRaw.b, 1e-10f))};
    const Vec3 grayDensity = interpCurves(grayLog, film.logExposure, film.densityCurves);
    const Vec3 grayPrint = filmToPrintLogExposure(grayDensity, film, paper, illum);
    float logMean = (grayPrint.r + grayPrint.g + grayPrint.b) / 3.0f;
    const float factor = std::pow(10.0f, -logMean);

    char keyBuffer[192];
    std::snprintf(keyBuffer, sizeof(keyBuffer), "%s|%s|%.2f|%.2f",
                  film.id.c_str(), paper.id.c_str(),
                  static_cast<double>(settings.mFilterShift),
                  static_cast<double>(settings.yFilterShift));
    const std::string cacheKey(keyBuffer);
    auto cached = printLuts_.find(cacheKey);
    if (cached == printLuts_.end()) {
        Lut3D lut;
        lut.allocate(33);
        lut.minimum = {minimum.r, minimum.g, minimum.b};
        lut.maximum = {maximum.r, maximum.g, maximum.b};
        for (int x = 0; x < 33; ++x) {
            for (int y = 0; y < 33; ++y) {
                for (int z = 0; z < 33; ++z) {
                    Vec3 d;
                    for (int c = 0; c < 3; ++c) {
                        const int step = c == 0 ? x : c == 1 ? y : z;
                        d[c] = minimum[c] + (maximum[c] - minimum[c]) * step / 32.0f;
                    }
                    Vec3 value = filmToPrintLogExposure(d, film, paper, illum);
                    for (int c = 0; c < 3; ++c) value[c] += std::log10(factor);
                    for (int c = 0; c < 3; ++c) lut.at(x, y, z, c) = value[c];
                }
            }
        }
        if (printLuts_.size() >= 6) printLuts_.clear();
        cached = printLuts_.emplace(cacheKey, std::move(lut)).first;
    }
    const Lut3D& lut = cached->second;
    Image printDensityImage(filmDensity.width, filmDensity.height);
    const bool positive = paper.type == "positive";
    parallelFor(filmDensity.height, [&](int y) {
        for (int x = 0; x < filmDensity.width; ++x) {
#ifdef SPEKTRA_DIRECT
            Vec3 logRaw = filmToPrintLogExposure(filmDensity.at(x, y), film, paper, illum);
            for (int c = 0; c < 3; ++c) logRaw[c] += std::log10(factor);
#else
            const Vec3 logRaw = lut.sample(filmDensity.at(x, y));
#endif
            Vec3 value;
            for (int c = 0; c < 3; ++c) {
                const auto& centers = paper.curveModel.centers[c];
                const auto& amps = paper.curveModel.amplitudes[c];
                const auto& sigmas = paper.curveModel.sigmas[c];
                float total = 0;
                for (size_t i = 0; i < centers.size(); ++i) {
                    const float z = (logRaw[c] - centers[i]) / std::max(sigmas[i], 0.05f);
                    total += amps[i] * normalCdf(positive ? -z : z);
                }
                value[c] = total;
            }
            printDensityImage.at(x, y) = value;
        }
    });
    return printDensityImage;
}

Vec3 Engine::densityToXyz(const Vec3& density, const Profile& source) const {
    Vec3 xyz{0, 0, 0};
    float normalization = 0.0f;
    for (int band = 0; band < 81; ++band) {
        const size_t i = static_cast<size_t>(band) * 3;
        const float densitySpectral =
            source.channelDensity[i] * density.r +
            source.channelDensity[i + 1] * density.g +
            source.channelDensity[i + 2] * density.b +
            source.baseDensity[band];
        if (!std::isfinite(densitySpectral)) continue;
        const float value = illuminant(source.viewingIlluminant, band).r;
        const float light = std::pow(10.0f, -densitySpectral) * value;
        xyz.r += light * cmfs_[i];
        xyz.g += light * cmfs_[i + 1];
        xyz.b += light * cmfs_[i + 2];
        normalization += value * cmfs_[i + 1];
    }
    const float inverse = 1.0f / std::max(normalization, 1e-8f);
    return {xyz.r * inverse, xyz.g * inverse, xyz.b * inverse};
}

Image Engine::scan(const Image& density, const Settings& settings,
                   const Profile& source) const {
    const size_t curveCount = source.logExposure.size();
    Vec3 minimum{1e9f, 1e9f, 1e9f};
    Vec3 maximum{-1e9f, -1e9f, -1e9f};
    for (size_t i = 0; i < curveCount; ++i) {
        for (int c = 0; c < 3; ++c) {
            const float value = source.densityCurves[i * 3 + c];
            if (!std::isfinite(value)) continue;
            minimum[c] = std::min(minimum[c], value);
            maximum[c] = std::max(maximum[c], value);
        }
    }
    if (settings.scanFilm) {
        // Upstream uses -grain.density_min as the lower bound for negative scans.
        minimum = {-0.03f, -0.03f, -0.03f};
    }
    for (int c = 0; c < 3; ++c) {
        if (!std::isfinite(minimum[c])) minimum[c] = 0.0f;
        if (!std::isfinite(maximum[c])) maximum[c] = 1.0f;
        if (maximum[c] <= minimum[c]) maximum[c] = minimum[c] + 0.1f;
    }

    char keyBuffer[128];
    std::snprintf(keyBuffer, sizeof(keyBuffer), "%s|%d",
                  source.id.c_str(), settings.scanFilm ? 1 : 0);
    const std::string cacheKey(keyBuffer);
    auto cached = scanLuts_.find(cacheKey);
    if (cached == scanLuts_.end()) {
        Lut3D lut;
        lut.allocate(33);
        lut.minimum = {minimum.r, minimum.g, minimum.b};
        lut.maximum = {maximum.r, maximum.g, maximum.b};
        for (int x = 0; x < 33; ++x) {
            for (int y = 0; y < 33; ++y) {
                for (int z = 0; z < 33; ++z) {
                    Vec3 d;
                    for (int c = 0; c < 3; ++c) {
                        const int step = c == 0 ? x : c == 1 ? y : z;
                        d[c] = minimum[c] + (maximum[c] - minimum[c]) * step / 32.0f;
                    }
                    const Vec3 xyz = densityToXyz(d, source);
                    for (int c = 0; c < 3; ++c) lut.at(x, y, z, c) = xyz[c];
                }
            }
        }
        if (scanLuts_.size() >= 8) scanLuts_.clear();
        cached = scanLuts_.emplace(cacheKey, std::move(lut)).first;
    }
    const Lut3D& lut = cached->second;

    Vec3 white{0, 0, 0};
    for (int band = 0; band < 81; ++band) {
        const float value = illuminant(source.viewingIlluminant, band).r;
        white.r += value * cmfs_[band * 3];
        white.g += value * cmfs_[band * 3 + 1];
        white.b += value * cmfs_[band * 3 + 2];
    }
    const float whiteY = std::max(white.g, 1e-8f);
    const float whiteArray[3] = {white.r / whiteY, 1.0f, white.b / whiteY};
    const auto adapt = bradford(whiteArray, kD65White);

    Image out(density.width, density.height);
    parallelFor(density.height, [&](int y) {
        for (int x = 0; x < density.width; ++x) {
#ifdef SPEKTRA_DIRECT
            const Vec3 xyz = densityToXyz(density.at(x, y), source);
#else
            const Vec3 xyz = lut.sample(density.at(x, y));
#endif
            Vec3 rgb = multiply(kXyzD65ToSrgb, multiply(adapt.data(), xyz));
            rgb = compressOutput(rgb);
            out.at(x, y) = {linearToSrgb(rgb.r), linearToSrgb(rgb.g), linearToSrgb(rgb.b)};
        }
    });
    return out;
}

Vec3 Engine::compressOutput(const Vec3& rgb) const {
    if (gamutSize_ < 2 || gamutLut_.empty()) return compressGamut(rgb);
    float coordinate[3];
    for (int c = 0; c < 3; ++c) {
        const float range = gamutMax_ - gamutMin_;
        coordinate[c] = range > 1e-8f
            ? std::clamp((rgb[c] - gamutMin_) / range, 0.0f, 1.0f)
            : 0.0f;
        if (gamutCubeRoot_) coordinate[c] = std::cbrt(coordinate[c]);
        coordinate[c] *= gamutSize_ - 1;
    }
    const int x0 = static_cast<int>(coordinate[0]);
    const int y0 = static_cast<int>(coordinate[1]);
    const int z0 = static_cast<int>(coordinate[2]);
    const int x1 = std::min(x0 + 1, gamutSize_ - 1);
    const int y1 = std::min(y0 + 1, gamutSize_ - 1);
    const int z1 = std::min(z0 + 1, gamutSize_ - 1);
    const float fx = coordinate[0] - x0;
    const float fy = coordinate[1] - y0;
    const float fz = coordinate[2] - z0;
    Vec3 result;
    for (int c = 0; c < 3; ++c) {
        auto at = [&](int x, int y, int z) {
            return gamutLut_[
                ((static_cast<size_t>(x) * gamutSize_ + y) * gamutSize_ + z) * 3 + c];
        };
        const float c00 = at(x0, y0, z0) * (1 - fx) + at(x1, y0, z0) * fx;
        const float c10 = at(x0, y1, z0) * (1 - fx) + at(x1, y1, z0) * fx;
        const float c01 = at(x0, y0, z1) * (1 - fx) + at(x1, y0, z1) * fx;
        const float c11 = at(x0, y1, z1) * (1 - fx) + at(x1, y1, z1) * fx;
        const float c0 = c00 * (1 - fy) + c10 * fy;
        const float c1 = c01 * (1 - fy) + c11 * fy;
        result[c] = c0 * (1 - fz) + c1 * fz;
    }
    return result;
}

Image Engine::render(const Image& linearProPhoto, const Settings& settings) const {
    const Profile& film = profile(settings.stockId);
    Image exposed = exposeFilm(linearProPhoto, settings, film);
    Image developed = developFilm(exposed, settings, film);
    if (settings.scanFilm) return scan(developed, settings, film);
    // Direct scan uses a mode id, not a paper profile, so resolve the paper
    // only for the printing path.
    const Profile& paper = profile(settings.paperId);
    Image printed = printDensity(developed, settings, film, paper);
    return scan(printed, settings, paper);
}

} // namespace spektrafilm
