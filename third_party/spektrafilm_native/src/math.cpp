#include "../include/spektrafilm/math.hpp"

#include <algorithm>
#include <cmath>
#include <thread>
#include <vector>

namespace spektrafilm {

float erfApprox(float x) {
    const float sign = x < 0 ? -1.0f : 1.0f;
    const float ax = std::fabs(x);
    const float t = 1.0f / (1.0f + 0.3275911f * ax);
    const float y = 1.0f - (((((1.061405429f * t - 1.453152027f) * t) + 1.421413741f) * t
                             - 0.284496736f) * t + 0.254829592f) * t * std::exp(-ax * ax);
    return sign * y;
}

float normalCdf(float x) {
    return 0.5f * (1.0f + erfApprox(x * 0.70710678118f));
}

namespace {

std::vector<float> kernel(float sigma) {
    const int radius = static_cast<int>(3.0f * sigma + 0.5f);
    if (radius <= 0) return {1.0f};
    std::vector<float> k(static_cast<size_t>(radius) * 2 + 1);
    float total = 0;
    for (int i = -radius; i <= radius; ++i) {
        const float value = std::exp(-0.5f * (i / sigma) * (i / sigma));
        k[i + radius] = value;
        total += value;
    }
    for (float& value : k) value /= total;
    return k;
}

float samplePlane(const std::vector<float>& plane, int width, int height, int x, int y) {
    return plane[static_cast<size_t>(std::clamp(y, 0, height - 1)) * width
                 + std::clamp(x, 0, width - 1)];
}

} // namespace

namespace {

// Young & van Vliet recursive Gaussian, matching the upstream large-sigma path.
void blurPlaneIIR(std::vector<float>& plane, int width, int height, float sigma) {
    const float q = sigma >= 2.5f
        ? 0.98711f * sigma - 0.96330f
        : 3.97156f - 4.14554f * std::sqrt(std::max(1.0f - 0.26891f * sigma, 0.0f));
    const float q2 = q * q;
    const float q3 = q2 * q;
    const float b0 = 1.57825f + 2.44413f * q + 1.4281f * q2 + 0.422205f * q3;
    const float b1 = 2.44413f * q + 2.85619f * q2 + 1.26661f * q3;
    const float b2 = -(1.4281f * q2 + 1.26661f * q3);
    const float b3 = 0.422205f * q3;
    const float B = 1.0f - (b1 + b2 + b3) / b0;
    const float B1 = b1 / b0;
    const float B2 = b2 / b0;
    const float B3 = b3 / b0;

    std::vector<float> temp(plane.size());
    parallelFor(height, [&](int y) {
        const size_t row = static_cast<size_t>(y) * width;
        float w1 = plane[row], w2 = w1, w3 = w1;
        for (int x = 0; x < width; ++x) {
            const float w = B * plane[row + x] + B1 * w1 + B2 * w2 + B3 * w3;
            temp[row + x] = w;
            w3 = w2; w2 = w1; w1 = w;
        }
        float y1 = temp[row + width - 1], y2 = y1, y3 = y1;
        for (int x = width - 1; x >= 0; --x) {
            const float value = B * temp[row + x] + B1 * y1 + B2 * y2 + B3 * y3;
            temp[row + x] = value;
            y3 = y2; y2 = y1; y1 = value;
        }
    });
    parallelFor(width, [&](int x) {
        float w1 = temp[x], w2 = w1, w3 = w1;
        for (int y = 0; y < height; ++y) {
            const size_t i = static_cast<size_t>(y) * width + x;
            const float w = B * temp[i] + B1 * w1 + B2 * w2 + B3 * w3;
            plane[i] = w;
            w3 = w2; w2 = w1; w1 = w;
        }
        float y1 = plane[static_cast<size_t>(height - 1) * width + x], y2 = y1, y3 = y1;
        for (int y = height - 1; y >= 0; --y) {
            const size_t i = static_cast<size_t>(y) * width + x;
            const float value = B * plane[i] + B1 * y1 + B2 * y2 + B3 * y3;
            plane[i] = value;
            y3 = y2; y2 = y1; y1 = value;
        }
    });
}

} // namespace

void blurPlane(std::vector<float>& plane, int width, int height, float sigma) {
    if (sigma <= 0.0f || width <= 0 || height <= 0) return;
    if (sigma >= 3.0f) {
        blurPlaneIIR(plane, width, height, sigma);
        return;
    }
    const auto k = kernel(sigma);
    const int radius = static_cast<int>(k.size() / 2);
    std::vector<float> horizontal(plane.size());
    parallelFor(height, [&](int y) {
        for (int x = 0; x < width; ++x) {
            float sum = 0;
            for (int i = -radius; i <= radius; ++i) {
                sum += samplePlane(plane, width, height, x + i, y) * k[i + radius];
            }
            horizontal[static_cast<size_t>(y) * width + x] = sum;
        }
    });
    parallelFor(height, [&](int y) {
        for (int x = 0; x < width; ++x) {
            float sum = 0;
            for (int i = -radius; i <= radius; ++i) {
                sum += samplePlane(horizontal, width, height, x, y + i) * k[i + radius];
            }
            plane[static_cast<size_t>(y) * width + x] = sum;
        }
    });
}

void exponentialPlane(std::vector<float>& plane, int width, int height,
                      float decayPixels) {
    if (decayPixels <= 0.0f) return;
    constexpr float fits[3][2] = {
        {0.1633f, 0.5360f}, {0.6496f, 1.5236f}, {0.1870f, 2.7684f},
    };
    std::vector<float> result(plane.size(), 0.0f);
    for (const auto& fit : fits) {
        std::vector<float> component = plane;
        blurPlane(component, width, height, fit[1] * decayPixels);
        for (size_t i = 0; i < result.size(); ++i) result[i] += fit[0] * component[i];
    }
    plane.swap(result);
}

void gaussian(Image& image, float sigmaPixels) {
    if (sigmaPixels <= 0.0f) return;
    for (int c = 0; c < 3; ++c) {
        std::vector<float> plane(static_cast<size_t>(image.width) * image.height);
        for (size_t i = 0; i < plane.size(); ++i) plane[i] = image.rgb[i * 3 + c];
        blurPlane(plane, image.width, image.height, sigmaPixels);
        for (size_t i = 0; i < plane.size(); ++i) image.rgb[i * 3 + c] = plane[i];
    }
}

void gaussianRgb(Image& image, const Vec3& sigmaPixels) {
    for (int c = 0; c < 3; ++c) {
        std::vector<float> plane(static_cast<size_t>(image.width) * image.height);
        for (size_t i = 0; i < plane.size(); ++i) plane[i] = image.rgb[i * 3 + c];
        blurPlane(plane, image.width, image.height, sigmaPixels[c]);
        for (size_t i = 0; i < plane.size(); ++i) image.rgb[i * 3 + c] = plane[i];
    }
}

void exponential(Image& image, float decayPixels) {
    for (int c = 0; c < 3; ++c) {
        std::vector<float> plane(static_cast<size_t>(image.width) * image.height);
        for (size_t i = 0; i < plane.size(); ++i) plane[i] = image.rgb[i * 3 + c];
        exponentialPlane(plane, image.width, image.height, decayPixels);
        for (size_t i = 0; i < plane.size(); ++i) image.rgb[i * 3 + c] = plane[i];
    }
}

Vec3 interpolateDensity(const Vec3& logExposure, const Profile& profile, float gamma) {
    Vec3 density;
    const auto& x = profile.logExposure;
    const size_t n = x.size();
    for (int c = 0; c < 3; ++c) {
        const float target = logExposure[c] / gamma;
        if (target <= x.front()) { density[c] = profile.densityCurves[c]; continue; }
        if (target >= x.back()) { density[c] = profile.densityCurves[(n - 1) * 3 + c]; continue; }
        size_t lo = 0, hi = n - 1;
        while (hi - lo > 1) {
            const size_t mid = (lo + hi) / 2;
            if (x[mid] <= target) lo = mid; else hi = mid;
        }
        const float span = x[hi] - x[lo];
        const float t = span > 1e-8f ? (target - x[lo]) / span : 0.0f;
        density[c] = profile.densityCurves[lo * 3 + c] * (1 - t)
                   + profile.densityCurves[hi * 3 + c] * t;
    }
    return density;
}

} // namespace spektrafilm
