#include <jni.h>
#include <android/log.h>
#include <array>
#include <atomic>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <algorithm>

#include "libraw/libraw.h"
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"

#define LOG_TAG "ZyncRaw"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

namespace {

std::atomic<bool> gCancel{false};

struct GradeParams {
    float exposure = 0.0f;
    float contrast = 0.0f;
    float saturation = 0.0f;
    float temperature = 0.0f;
    float tint = 0.0f;
    float highlights = 0.0f;
    float shadows = 0.0f;
    float whites = 0.0f;
    float blacks = 0.0f;
    float vibrance = 0.0f;
    float vignette = 0.0f;
    float grain = 0.0f;
    float sharpening = 0.0f;
    float noiseReduction = 0.0f;
    float lensDistortion = 0.0f;
    float lensVignette = 0.0f;
    float chromaticAberration = 0.0f;
    int toneCurveCount = 0;
    std::array<float, 10> toneCurve{};
    int hslCount = 0;
    std::array<float, 24> hsl{};
    std::array<float, 9> wheels{};
    float lutStrength = 1.0f;
};

struct Lut3D {
    int size = 0;
    std::vector<float> data;

    bool valid() const { return size > 1 && data.size() >= static_cast<size_t>(size) * size * size * 3; }

    void sample(float r, float g, float b, float& outR, float& outG, float& outB) const {
        if (!valid()) {
            outR = r;
            outG = g;
            outB = b;
            return;
        }
        const float x = std::clamp(r, 0.0f, 1.0f) * (size - 1);
        const float y = std::clamp(g, 0.0f, 1.0f) * (size - 1);
        const float z = std::clamp(b, 0.0f, 1.0f) * (size - 1);
        const int x0 = static_cast<int>(std::floor(x));
        const int y0 = static_cast<int>(std::floor(y));
        const int z0 = static_cast<int>(std::floor(z));
        const int x1 = std::min(x0 + 1, size - 1);
        const int y1 = std::min(y0 + 1, size - 1);
        const int z1 = std::min(z0 + 1, size - 1);
        const float fx = x - x0;
        const float fy = y - y0;
        const float fz = z - z0;
        auto at = [&](int xx, int yy, int zz, int c) -> float {
            const size_t index = ((static_cast<size_t>(xx) * size + yy) * size + zz) * 3 + c;
            return data[index];
        };
        float values[3] = {0, 0, 0};
        for (int c = 0; c < 3; ++c) {
            const float c00 = at(x0, y0, z0, c) * (1 - fx) + at(x1, y0, z0, c) * fx;
            const float c10 = at(x0, y1, z0, c) * (1 - fx) + at(x1, y1, z0, c) * fx;
            const float c01 = at(x0, y0, z1, c) * (1 - fx) + at(x1, y0, z1, c) * fx;
            const float c11 = at(x0, y1, z1, c) * (1 - fx) + at(x1, y1, z1, c) * fx;
            const float c0 = c00 * (1 - fy) + c10 * fy;
            const float c1 = c01 * (1 - fy) + c11 * fy;
            values[c] = c0 * (1 - fz) + c1 * fz;
        }
        outR = values[0];
        outG = values[1];
        outB = values[2];
    }
};

std::string jstringToStd(JNIEnv* env, jstring value) {
    if (value == nullptr) return {};
    const char* chars = env->GetStringUTFChars(value, nullptr);
    if (chars == nullptr) return {};
    std::string result(chars);
    env->ReleaseStringUTFChars(value, chars);
    return result;
}

GradeParams readGradeParams(JNIEnv* env, jfloatArray values) {
    GradeParams p;
    if (values == nullptr) return p;
    const jsize length = env->GetArrayLength(values);
    const jsize count = std::min<jsize>(length, 64);
    std::vector<float> v(static_cast<size_t>(count));
    if (count > 0) env->GetFloatArrayRegion(values, 0, count, v.data());
    auto get = [&](int index, float fallback = 0.0f) -> float {
        return index >= 0 && index < static_cast<int>(v.size()) ? v[index] : fallback;
    };
    p.exposure = get(0);
    p.contrast = get(1);
    p.saturation = get(2);
    p.temperature = get(3);
    p.tint = get(4);
    p.highlights = get(5);
    p.shadows = get(6);
    p.whites = get(7);
    p.blacks = get(8);
    p.vibrance = get(9);
    p.vignette = get(10);
    p.grain = get(11);
    p.sharpening = get(12);
    p.noiseReduction = get(13);
    p.lensDistortion = get(14);
    p.lensVignette = get(15);
    p.chromaticAberration = get(16);
    p.toneCurveCount = std::clamp(static_cast<int>(std::round(get(17))), 0, 5);
    for (int i = 0; i < p.toneCurveCount; ++i) {
        p.toneCurve[i * 2] = get(18 + i * 2);
        p.toneCurve[i * 2 + 1] = get(19 + i * 2);
    }
    p.hslCount = std::clamp(static_cast<int>(std::round(get(28))), 0, 8);
    for (int i = 0; i < p.hslCount; ++i) {
        p.hsl[i * 3] = get(29 + i * 3);
        p.hsl[i * 3 + 1] = get(30 + i * 3);
        p.hsl[i * 3 + 2] = get(31 + i * 3);
    }
    for (int i = 0; i < 3; ++i) {
        p.wheels[i * 3] = get(53 + i * 3);
        p.wheels[i * 3 + 1] = get(54 + i * 3);
        p.wheels[i * 3 + 2] = get(55 + i * 3);
    }
    return p;
}

Lut3D parseCube(const std::string& path) {
    Lut3D lut;
    if (path.empty()) return lut;
    std::ifstream input(path);
    if (!input.good()) return lut;
    std::vector<std::array<float, 3>> rows;
    std::string line;
    while (std::getline(input, line)) {
        if (line.empty() || line[0] == '#') continue;
        const auto hash = line.find('#');
        if (hash != std::string::npos) line = line.substr(0, hash);
        std::istringstream stream(line);
        std::string first;
        stream >> first;
        if (first == "LUT_3D_SIZE") {
            stream >> lut.size;
        } else if (first == "LUT_1D_SIZE" || first == "TITLE" || first == "DOMAIN_MIN" || first == "DOMAIN_MAX") {
            continue;
        } else {
            std::istringstream values(line);
            float r = 0, g = 0, b = 0;
            if (values >> r >> g >> b) rows.push_back({r, g, b});
        }
    }
    if (lut.size <= 1) return {};
    const size_t expected = static_cast<size_t>(lut.size) * lut.size * lut.size;
    if (rows.size() < expected) return {};
    lut.data.resize(expected * 3);
    for (size_t i = 0; i < expected; ++i) {
        lut.data[i * 3] = rows[i][0];
        lut.data[i * 3 + 1] = rows[i][1];
        lut.data[i * 3 + 2] = rows[i][2];
    }
    return lut;
}

float smoothstep(float edge0, float edge1, float x) {
    const float t = std::clamp((x - edge0) / std::max(1e-6f, edge1 - edge0), 0.0f, 1.0f);
    return t * t * (3.0f - 2.0f * t);
}

float lumaOf(float r, float g, float b) {
    return 0.299f * r + 0.587f * g + 0.114f * b;
}

void rgbToHsl(float r, float g, float b, float& h, float& s, float& l) {
    const float maxV = std::max({r, g, b});
    const float minV = std::min({r, g, b});
    l = (maxV + minV) * 0.5f;
    const float delta = maxV - minV;
    if (delta < 1e-6f) {
        h = 0.0f;
        s = 0.0f;
        return;
    }
    s = l > 0.5f ? delta / std::max(1e-6f, 2.0f - maxV - minV)
                 : delta / std::max(1e-6f, maxV + minV);
    if (maxV == r) {
        h = (g - b) / delta + (g < b ? 6.0f : 0.0f);
    } else if (maxV == g) {
        h = (b - r) / delta + 2.0f;
    } else {
        h = (r - g) / delta + 4.0f;
    }
    h *= 60.0f;
}

float hueToRgb(float p, float q, float t) {
    if (t < 0.0f) t += 1.0f;
    if (t > 1.0f) t -= 1.0f;
    if (t < 1.0f / 6.0f) return p + (q - p) * 6.0f * t;
    if (t < 1.0f / 2.0f) return q;
    if (t < 2.0f / 3.0f) return p + (q - p) * (2.0f / 3.0f - t) * 6.0f;
    return p;
}

void hslToRgb(float h, float s, float l, float& r, float& g, float& b) {
    h = std::fmod(h, 360.0f);
    if (h < 0.0f) h += 360.0f;
    h /= 360.0f;
    if (s < 1e-6f) {
        r = g = b = l;
        return;
    }
    const float q = l < 0.5f ? l * (1.0f + s) : l + s - l * s;
    const float p = 2.0f * l - q;
    r = hueToRgb(p, q, h + 1.0f / 3.0f);
    g = hueToRgb(p, q, h);
    b = hueToRgb(p, q, h - 1.0f / 3.0f);
}

float evaluateCurve(const GradeParams& p, float value) {
    if (p.toneCurveCount < 2) return value;
    float x0 = p.toneCurve[0];
    float y0 = p.toneCurve[1];
    if (value <= x0) return y0;
    for (int i = 1; i < p.toneCurveCount; ++i) {
        const float x1 = p.toneCurve[i * 2];
        const float y1 = p.toneCurve[i * 2 + 1];
        if (value <= x1) {
            const float span = x1 - x0;
            return span <= 1e-6f ? y1 : y0 + (y1 - y0) * ((value - x0) / span);
        }
        x0 = x1;
        y0 = y1;
    }
    return y0;
}

void applyHslAndWheels(float& r, float& g, float& b, const GradeParams& p) {
    float h, s, l;
    rgbToHsl(r, g, b, h, s, l);
    float hueShift = 0.0f;
    float satShift = 0.0f;
    float lumShift = 0.0f;

    static constexpr float centers[8] = {0.0f, 30.0f, 60.0f, 120.0f, 180.0f, 240.0f, 280.0f, 320.0f};
    for (int i = 0; i < p.hslCount; ++i) {
        const float distance = std::min(std::abs(h - centers[i]), 360.0f - std::abs(h - centers[i]));
        const float weight = std::clamp(1.0f - distance / 45.0f, 0.0f, 1.0f);
        hueShift += p.hsl[i * 3] * weight;
        satShift += p.hsl[i * 3 + 1] * weight;
        lumShift += p.hsl[i * 3 + 2] * weight;
    }

    const float shadowWeight = 1.0f - smoothstep(0.0f, 0.5f, l);
    const float highlightWeight = smoothstep(0.5f, 1.0f, l);
    const float midWeight = std::max(0.0f, 1.0f - std::abs(l - 0.5f) * 2.0f);
    const float wheelWeights[3] = {shadowWeight, midWeight, highlightWeight};
    for (int i = 0; i < 3; ++i) {
        hueShift += p.wheels[i * 3] * wheelWeights[i];
        satShift += p.wheels[i * 3 + 1] * wheelWeights[i];
        lumShift += p.wheels[i * 3 + 2] * wheelWeights[i];
    }

    if (std::abs(hueShift) + std::abs(satShift) + std::abs(lumShift) < 1e-6f) return;
    h += hueShift;
    s = std::clamp(s * (1.0f + satShift / 100.0f), 0.0f, 1.0f);
    l = std::clamp(l + lumShift / 100.0f * 0.18f, 0.0f, 1.0f);
    hslToRgb(h, s, l, r, g, b);
}

void applyGrade(float& r, float& g, float& b, const GradeParams& p, const Lut3D& lut) {
    const float exposureGain = std::pow(2.0f, (p.exposure / 100.0f) * 2.0f);
    const float contrastValue = std::clamp(p.contrast / 100.0f, -0.95f, 0.95f);
    const float contrastFactor = (1.0f + contrastValue) / (1.0001f - contrastValue);
    const float sat = std::clamp(1.0f + p.saturation / 100.0f, 0.0f, 2.5f);
    const float sr = (1.0f - sat) * 0.299f;
    const float sg = (1.0f - sat) * 0.587f;
    const float sb = (1.0f - sat) * 0.114f;
    const float temp = std::clamp(p.temperature / 100.0f, -1.0f, 1.0f);
    const float tint = std::clamp(p.tint / 100.0f, -1.0f, 1.0f);
    const float rGain = exposureGain * (1.0f + temp * 0.22f) * (1.0f + tint * 0.10f);
    const float gGain = exposureGain * (1.0f - tint * 0.18f);
    const float bGain = exposureGain * (1.0f - temp * 0.22f) * (1.0f + tint * 0.10f);
    const float offset = (1.0f - contrastFactor) * 0.5f;

    float rr = std::clamp((sr + sat) * contrastFactor * rGain * r + sg * contrastFactor * rGain * g + sb * contrastFactor * rGain * b + offset, 0.0f, 1.0f);
    float gg = std::clamp(sr * contrastFactor * gGain * r + (sg + sat) * contrastFactor * gGain * g + sb * contrastFactor * gGain * b + offset, 0.0f, 1.0f);
    float bb = std::clamp(sr * contrastFactor * bGain * r + sg * contrastFactor * bGain * g + (sb + sat) * contrastFactor * bGain * b + offset, 0.0f, 1.0f);

    const float luma = lumaOf(rr, gg, bb);
    const float highWeight = smoothstep(0.5f, 1.0f, luma);
    const float shadowWeight = 1.0f - smoothstep(0.0f, 0.5f, luma);
    rr = std::clamp(rr + p.highlights / 100.0f * 0.22f * highWeight, 0.0f, 1.0f);
    gg = std::clamp(gg + p.highlights / 100.0f * 0.22f * highWeight, 0.0f, 1.0f);
    bb = std::clamp(bb + p.highlights / 100.0f * 0.22f * highWeight, 0.0f, 1.0f);
    rr = std::clamp(rr + p.shadows / 100.0f * 0.22f * shadowWeight, 0.0f, 1.0f);
    gg = std::clamp(gg + p.shadows / 100.0f * 0.22f * shadowWeight, 0.0f, 1.0f);
    bb = std::clamp(bb + p.shadows / 100.0f * 0.22f * shadowWeight, 0.0f, 1.0f);
    rr = std::clamp(rr + p.whites / 100.0f * 0.12f * luma, 0.0f, 1.0f);
    gg = std::clamp(gg + p.whites / 100.0f * 0.12f * luma, 0.0f, 1.0f);
    bb = std::clamp(bb + p.whites / 100.0f * 0.12f * luma, 0.0f, 1.0f);
    rr = std::clamp(rr + p.blacks / 100.0f * 0.12f * (1.0f - luma), 0.0f, 1.0f);
    gg = std::clamp(gg + p.blacks / 100.0f * 0.12f * (1.0f - luma), 0.0f, 1.0f);
    bb = std::clamp(bb + p.blacks / 100.0f * 0.12f * (1.0f - luma), 0.0f, 1.0f);

    if (std::abs(p.vibrance) > 1e-6f) {
        const float maxV = std::max({rr, gg, bb});
        const float minV = std::min({rr, gg, bb});
        const float currentSat = maxV - minV;
        const float boost = 1.0f + p.vibrance / 100.0f * (1.0f - currentSat) * 0.6f;
        const float pixelLuma = lumaOf(rr, gg, bb);
        rr = std::clamp(pixelLuma + (rr - pixelLuma) * boost, 0.0f, 1.0f);
        gg = std::clamp(pixelLuma + (gg - pixelLuma) * boost, 0.0f, 1.0f);
        bb = std::clamp(pixelLuma + (bb - pixelLuma) * boost, 0.0f, 1.0f);
    }

    if (p.toneCurveCount >= 2) {
        rr = std::clamp(evaluateCurve(p, rr), 0.0f, 1.0f);
        gg = std::clamp(evaluateCurve(p, gg), 0.0f, 1.0f);
        bb = std::clamp(evaluateCurve(p, bb), 0.0f, 1.0f);
    }
    if (p.hslCount > 0 || std::abs(p.wheels[0]) + std::abs(p.wheels[1]) + std::abs(p.wheels[2]) +
            std::abs(p.wheels[3]) + std::abs(p.wheels[4]) + std::abs(p.wheels[5]) +
            std::abs(p.wheels[6]) + std::abs(p.wheels[7]) + std::abs(p.wheels[8]) > 1e-6f) {
        applyHslAndWheels(rr, gg, bb, p);
    }

    if (lut.valid()) {
        float lr = rr, lg = gg, lb = bb;
        lut.sample(rr, gg, bb, lr, lg, lb);
        const float strength = std::clamp(p.lutStrength, 0.0f, 1.0f);
        r = rr + (lr - rr) * strength;
        g = gg + (lg - gg) * strength;
        b = bb + (lb - bb) * strength;
    } else {
        r = rr;
        g = gg;
        b = bb;
    }
}

float sampleChannel(const std::vector<uint8_t>& src, int width, int height, float x, float y, int channel) {
    x = std::clamp(x, 0.0f, static_cast<float>(width - 1));
    y = std::clamp(y, 0.0f, static_cast<float>(height - 1));
    const int x0 = static_cast<int>(std::floor(x));
    const int y0 = static_cast<int>(std::floor(y));
    const int x1 = std::min(x0 + 1, width - 1);
    const int y1 = std::min(y0 + 1, height - 1);
    const float fx = x - x0;
    const float fy = y - y0;
    auto at = [&](int xx, int yy) -> float {
        return src[(static_cast<size_t>(yy) * width + xx) * 4 + channel] / 255.0f;
    };
    const float top = at(x0, y0) * (1.0f - fx) + at(x1, y0) * fx;
    const float bottom = at(x0, y1) * (1.0f - fx) + at(x1, y1) * fx;
    return top * (1.0f - fy) + bottom * fy;
}

void applySpatialEffects(std::vector<uint8_t>& rgba, int width, int height, const GradeParams& p) {
    if (width <= 1 || height <= 1) return;
    const bool needsSharpen = std::abs(p.sharpening) > 0.01f;
    const bool needsNoise = std::abs(p.noiseReduction) > 0.01f;
    const bool needsLens = std::abs(p.lensDistortion) > 0.01f || std::abs(p.chromaticAberration) > 0.01f;
    if (!needsSharpen && !needsNoise && !needsLens) return;

    const std::vector<uint8_t> source = rgba;
    if (needsSharpen || needsNoise) {
        const float noiseAmount = std::clamp(p.noiseReduction / 100.0f, 0.0f, 1.0f) * 0.75f;
        const float sharpenAmount = std::clamp(p.sharpening / 100.0f, 0.0f, 1.0f) * 1.5f;
        for (int y = 0; y < height; ++y) {
            if (gCancel.load()) return;
            for (int x = 0; x < width; ++x) {
                const size_t index = (static_cast<size_t>(y) * width + x) * 4;
                for (int c = 0; c < 3; ++c) {
                    float sum = 0.0f;
                    int count = 0;
                    for (int dy = -1; dy <= 1; ++dy) {
                        const int yy = std::clamp(y + dy, 0, height - 1);
                        for (int dx = -1; dx <= 1; ++dx) {
                            const int xx = std::clamp(x + dx, 0, width - 1);
                            sum += source[(static_cast<size_t>(yy) * width + xx) * 4 + c] / 255.0f;
                            ++count;
                        }
                    }
                    const float original = source[index + c] / 255.0f;
                    const float blurred = sum / std::max(1, count);
                    const float denoised = original * (1.0f - noiseAmount) + blurred * noiseAmount;
                    const float sharpened = denoised + (denoised - blurred) * sharpenAmount;
                    rgba[index + c] = static_cast<uint8_t>(std::clamp(sharpened, 0.0f, 1.0f) * 255.0f + 0.5f);
                }
            }
        }
    }

    if (needsLens) {
        const float cx = (width - 1) * 0.5f;
        const float cy = (height - 1) * 0.5f;
        const float maxRadius = std::max(1.0f, std::sqrt(cx * cx + cy * cy));
        const float distortion = std::clamp(p.lensDistortion / 100.0f, -1.0f, 1.0f) * 0.35f;
        const float chroma = std::clamp(p.chromaticAberration / 100.0f, 0.0f, 1.0f) * 0.008f;
        const std::vector<uint8_t> lensSource = rgba;
        for (int y = 0; y < height; ++y) {
            if (gCancel.load()) return;
            for (int x = 0; x < width; ++x) {
                const float nx = (x - cx) / maxRadius;
                const float ny = (y - cy) / maxRadius;
                const float radius2 = nx * nx + ny * ny;
                const float scale = 1.0f + distortion * radius2;
                const float sx = cx + (x - cx) * scale;
                const float sy = cy + (y - cy) * scale;
                const size_t index = (static_cast<size_t>(y) * width + x) * 4;
                const float chromaScale = 1.0f + chroma * radius2;
                rgba[index] = static_cast<uint8_t>(std::clamp(sampleChannel(lensSource, width, height, cx + (sx - cx) * chromaScale, sy, 0), 0.0f, 1.0f) * 255.0f + 0.5f);
                rgba[index + 1] = static_cast<uint8_t>(std::clamp(sampleChannel(lensSource, width, height, sx, sy, 1), 0.0f, 1.0f) * 255.0f + 0.5f);
                rgba[index + 2] = static_cast<uint8_t>(std::clamp(sampleChannel(lensSource, width, height, cx + (sx - cx) / chromaScale, sy, 2), 0.0f, 1.0f) * 255.0f + 0.5f);
            }
        }
    }
}

bool encodeJpeg(const std::vector<uint8_t>& rgba, int width, int height, int quality, std::vector<uint8_t>& out) {
    out.clear();
    struct Context {
        std::vector<uint8_t>* out;
    } context{&out};
    auto write = [](void* ctx, void* data, int size) {
        auto* target = static_cast<Context*>(ctx);
        const auto* bytes = static_cast<const uint8_t*>(data);
        target->out->insert(target->out->end(), bytes, bytes + size);
    };
    return stbi_write_jpg_to_func(write, &context, width, height, 4, rgba.data(), quality) != 0;
}

struct RenderResult {
    bool ok = false;
    std::string error;
    int width = 0;
    int height = 0;
    std::vector<uint8_t> jpeg;
};

RenderResult renderRaw(const std::string& path, int maxEdge, const GradeParams& grade, const std::string& lutPath, int quality) {
    RenderResult result;
    LibRaw raw;
    int ret = raw.open_file(path.c_str());
    if (ret != LIBRAW_SUCCESS) {
        result.error = libraw_strerror(ret);
        return result;
    }

    raw.imgdata.params.use_camera_wb = 1;
    raw.imgdata.params.output_bps = 16;
    raw.imgdata.params.output_color = 1; // sRGB output
    raw.imgdata.params.no_auto_bright = 0;
    raw.imgdata.params.half_size = maxEdge > 0 ? 1 : 0;

    ret = raw.unpack();
    if (ret != LIBRAW_SUCCESS) {
        result.error = libraw_strerror(ret);
        return result;
    }
    ret = raw.dcraw_process();
    if (ret != LIBRAW_SUCCESS) {
        result.error = libraw_strerror(ret);
        return result;
    }

    int err = 0;
    libraw_processed_image_t* image = raw.dcraw_make_mem_image(&err);
    if (image == nullptr || image->type != LIBRAW_IMAGE_BITMAP || image->colors < 3) {
        result.error = "LibRaw 无法生成位图";
        if (image != nullptr) LibRaw::dcraw_clear_mem(image);
        return result;
    }

    const int srcWidth = image->width;
    const int srcHeight = image->height;
    const int srcChannels = image->colors;
    const bool sixteenBit = image->bits == 16;
    const auto* src16 = reinterpret_cast<const uint16_t*>(image->data);
    const auto* src8 = reinterpret_cast<const uint8_t*>(image->data);

    int outWidth = srcWidth;
    int outHeight = srcHeight;
    if (maxEdge > 0 && (srcWidth > maxEdge || srcHeight > maxEdge)) {
        const float scale = static_cast<float>(maxEdge) / static_cast<float>(std::max(srcWidth, srcHeight));
        outWidth = std::max(1, static_cast<int>(std::round(srcWidth * scale)));
        outHeight = std::max(1, static_cast<int>(std::round(srcHeight * scale)));
    }

    const Lut3D lut = parseCube(lutPath);
    std::vector<uint8_t> rgba(static_cast<size_t>(outWidth) * outHeight * 4);
    for (int y = 0; y < outHeight; ++y) {
        if (gCancel.load()) {
            result.error = "RAW 渲染已取消";
            LibRaw::dcraw_clear_mem(image);
            return result;
        }
        for (int x = 0; x < outWidth; ++x) {
            const int sx = std::min(srcWidth - 1, static_cast<int>((static_cast<int64_t>(x) * srcWidth) / outWidth));
            const int sy = std::min(srcHeight - 1, static_cast<int>((static_cast<int64_t>(y) * srcHeight) / outHeight));
            const size_t srcIndex = (static_cast<size_t>(sy) * srcWidth + sx) * srcChannels;
            float r, g, b;
            if (sixteenBit) {
                r = src16[srcIndex] / 65535.0f;
                g = src16[srcIndex + 1] / 65535.0f;
                b = src16[srcIndex + 2] / 65535.0f;
            } else {
                r = src8[srcIndex] / 255.0f;
                g = src8[srcIndex + 1] / 255.0f;
                b = src8[srcIndex + 2] / 255.0f;
            }
            applyGrade(r, g, b, grade, lut);
            const float nx = outWidth > 1 ? (static_cast<float>(x) / (outWidth - 1) - 0.5f) * 2.0f : 0.0f;
            const float ny = outHeight > 1 ? (static_cast<float>(y) / (outHeight - 1) - 0.5f) * 2.0f : 0.0f;
            const float radius2 = nx * nx + ny * ny;
            const float vignette = 1.0f + (grade.vignette + grade.lensVignette) / 100.0f * 0.55f * radius2;
            r = std::clamp(r * vignette, 0.0f, 1.0f);
            g = std::clamp(g * vignette, 0.0f, 1.0f);
            b = std::clamp(b * vignette, 0.0f, 1.0f);
            if (std::abs(grade.grain) > 0.01f) {
                const float hash = std::sin(x * 12.9898f + y * 78.233f) * 43758.5453f;
                const float noise = (hash - std::floor(hash) - 0.5f) * grade.grain / 100.0f * 0.08f;
                r = std::clamp(r + noise, 0.0f, 1.0f);
                g = std::clamp(g + noise, 0.0f, 1.0f);
                b = std::clamp(b + noise, 0.0f, 1.0f);
            }
            const size_t dstIndex = (static_cast<size_t>(y) * outWidth + x) * 4;
            rgba[dstIndex] = static_cast<uint8_t>(std::clamp(r, 0.0f, 1.0f) * 255.0f + 0.5f);
            rgba[dstIndex + 1] = static_cast<uint8_t>(std::clamp(g, 0.0f, 1.0f) * 255.0f + 0.5f);
            rgba[dstIndex + 2] = static_cast<uint8_t>(std::clamp(b, 0.0f, 1.0f) * 255.0f + 0.5f);
            rgba[dstIndex + 3] = 255;
        }
    }
    applySpatialEffects(rgba, outWidth, outHeight, grade);
    if (gCancel.load()) {
        result.error = "RAW 渲染已取消";
        LibRaw::dcraw_clear_mem(image);
        return result;
    }
    LibRaw::dcraw_clear_mem(image);

    if (!encodeJpeg(rgba, outWidth, outHeight, quality, result.jpeg)) {
        result.error = "JPEG 编码失败";
        return result;
    }
    result.ok = true;
    result.width = outWidth;
    result.height = outHeight;
    return result;
}

void putObject(JNIEnv* env, jobject map, jmethodID put, const char* key, jobject value) {
    jstring jkey = env->NewStringUTF(key);
    env->CallObjectMethod(map, put, jkey, value);
    env->DeleteLocalRef(jkey);
    if (value != nullptr) env->DeleteLocalRef(value);
}

jobject makeMap(JNIEnv* env) {
    jclass mapClass = env->FindClass("java/util/HashMap");
    jmethodID ctor = env->GetMethodID(mapClass, "<init>", "()V");
    return env->NewObject(mapClass, ctor);
}

void putInt(JNIEnv* env, jobject map, jmethodID put, const char* key, int value) {
    jclass cls = env->FindClass("java/lang/Integer");
    jmethodID valueOf = env->GetStaticMethodID(cls, "valueOf", "(I)Ljava/lang/Integer;");
    putObject(env, map, put, key, env->CallStaticObjectMethod(cls, valueOf, value));
}

void putFloat(JNIEnv* env, jobject map, jmethodID put, const char* key, float value) {
    jclass cls = env->FindClass("java/lang/Float");
    jmethodID valueOf = env->GetStaticMethodID(cls, "valueOf", "(F)Ljava/lang/Float;");
    putObject(env, map, put, key, env->CallStaticObjectMethod(cls, valueOf, value));
}

void putBool(JNIEnv* env, jobject map, jmethodID put, const char* key, bool value) {
    jclass cls = env->FindClass("java/lang/Boolean");
    jmethodID valueOf = env->GetStaticMethodID(cls, "valueOf", "(Z)Ljava/lang/Boolean;");
    putObject(env, map, put, key, env->CallStaticObjectMethod(cls, valueOf, value));
}

void putString(JNIEnv* env, jobject map, jmethodID put, const char* key, const std::string& value) {
    putObject(env, map, put, key, env->NewStringUTF(value.c_str()));
}

jmethodID mapPut(JNIEnv* env) {
    jclass mapClass = env->FindClass("java/util/Map");
    return env->GetMethodID(mapClass, "put", "(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;");
}

} // namespace

extern "C" JNIEXPORT jboolean JNICALL
Java_com_zync_app_RawProcessorBridge_nativeIsAvailable(JNIEnv*, jobject) {
    return JNI_TRUE;
}

extern "C" JNIEXPORT jobject JNICALL
Java_com_zync_app_RawProcessorBridge_nativeProbe(JNIEnv* env, jobject, jstring jpath) {
    const std::string path = jstringToStd(env, jpath);
    jobject map = makeMap(env);
    const jmethodID put = mapPut(env);
    if (path.empty()) {
        putBool(env, map, put, "supported", false);
        putString(env, map, put, "reason", "RAW 路径为空");
        return map;
    }
    LibRaw raw;
    const int ret = raw.open_file(path.c_str());
    if (ret != LIBRAW_SUCCESS) {
        putBool(env, map, put, "supported", false);
        putString(env, map, put, "reason", libraw_strerror(ret));
        return map;
    }
    putBool(env, map, put, "supported", true);
    putInt(env, map, put, "width", raw.imgdata.sizes.width);
    putInt(env, map, put, "height", raw.imgdata.sizes.height);
    putInt(env, map, put, "bitDepth", 16);
    putString(env, map, put, "cameraMake", raw.imgdata.idata.make);
    putString(env, map, put, "cameraModel", raw.imgdata.idata.model);
    putString(env, map, put, "lensModel", raw.imgdata.lens.Lens);
    putInt(env, map, put, "iso", static_cast<int>(raw.imgdata.other.iso_speed));
    putFloat(env, map, put, "aperture", raw.imgdata.other.aperture);
    std::ostringstream shutter;
    shutter << raw.imgdata.other.shutter;
    putString(env, map, put, "shutter", shutter.str());
    putFloat(env, map, put, "focalLength", raw.imgdata.other.focal_len);
    putInt(env, map, put, "orientation", raw.imgdata.sizes.flip);
    putBool(env, map, put, "hasEmbeddedPreview", raw.imgdata.thumbs_list.thumbcount > 0);
    putString(env, map, put, "reason", "");
    return map;
}

extern "C" JNIEXPORT jobject JNICALL
Java_com_zync_app_RawProcessorBridge_nativeRenderPreview(
    JNIEnv* env, jobject, jstring jpath, jint maxEdge, jfloatArray jparams, jstring jlutPath, jfloat lutStrength) {
    gCancel.store(false);
    GradeParams grade = readGradeParams(env, jparams);
    grade.lutStrength = lutStrength;
    const std::string path = jstringToStd(env, jpath);
    const std::string lutPath = jstringToStd(env, jlutPath);
    const RenderResult rendered = renderRaw(path, maxEdge, grade, lutPath, 92);
    jobject map = makeMap(env);
    const jmethodID put = mapPut(env);
    if (!rendered.ok) {
        putString(env, map, put, "error", rendered.error);
        return map;
    }
    jbyteArray bytes = env->NewByteArray(static_cast<jsize>(rendered.jpeg.size()));
    env->SetByteArrayRegion(bytes, 0, static_cast<jsize>(rendered.jpeg.size()), reinterpret_cast<const jbyte*>(rendered.jpeg.data()));
    putObject(env, map, put, "bytes", bytes);
    putInt(env, map, put, "width", rendered.width);
    putInt(env, map, put, "height", rendered.height);
    putBool(env, map, put, "isProxy", true);
    return map;
}

extern "C" JNIEXPORT jobject JNICALL
Java_com_zync_app_RawProcessorBridge_nativeRenderFull(
    JNIEnv* env, jobject, jstring jpath, jstring, jint quality, jfloatArray jparams, jstring jlutPath, jfloat lutStrength) {
    gCancel.store(false);
    GradeParams grade = readGradeParams(env, jparams);
    grade.lutStrength = lutStrength;
    const std::string path = jstringToStd(env, jpath);
    const std::string lutPath = jstringToStd(env, jlutPath);
    const RenderResult rendered = renderRaw(path, 0, grade, lutPath, quality);
    jobject map = makeMap(env);
    const jmethodID put = mapPut(env);
    if (!rendered.ok) {
        putString(env, map, put, "error", rendered.error);
        return map;
    }
    jbyteArray bytes = env->NewByteArray(static_cast<jsize>(rendered.jpeg.size()));
    env->SetByteArrayRegion(bytes, 0, static_cast<jsize>(rendered.jpeg.size()), reinterpret_cast<const jbyte*>(rendered.jpeg.data()));
    putObject(env, map, put, "bytes", bytes);
    putInt(env, map, put, "width", rendered.width);
    putInt(env, map, put, "height", rendered.height);
    putBool(env, map, put, "isProxy", false);
    return map;
}

extern "C" JNIEXPORT void JNICALL
Java_com_zync_app_RawProcessorBridge_nativeCancel(JNIEnv*, jobject) {
    gCancel.store(true);
}