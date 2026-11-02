#include "../include/spektrafilm/engine.hpp"

#include <android/log.h>
#include <jni.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <memory>
#include <mutex>
#include <sstream>
#include <string>
#include <unordered_map>
#include <vector>
#include <fstream>

#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"

#define LOG_TAG "ZyncSpektrafilm"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

namespace {

std::mutex gMutex;
std::unordered_map<std::string, std::shared_ptr<spektrafilm::Engine>> gEngines;

std::string toStd(JNIEnv* env, jstring value) {
    if (value == nullptr) return {};
    const char* chars = env->GetStringUTFChars(value, nullptr);
    if (chars == nullptr) return {};
    std::string result(chars);
    env->ReleaseStringUTFChars(value, chars);
    return result;
}

std::shared_ptr<spektrafilm::Engine> engineFor(const std::string& dataDirectory) {
    std::lock_guard<std::mutex> lock(gMutex);
    auto it = gEngines.find(dataDirectory);
    if (it != gEngines.end()) return it->second;
    auto engine = std::make_shared<spektrafilm::Engine>(dataDirectory);
    gEngines.emplace(dataDirectory, engine);
    return engine;
}

std::string escape(const std::string& text) {
    std::string out;
    out.reserve(text.size() + 8);
    for (char c : text) {
        if (c == '"' || c == '\\') out += '\\';
        out += c;
    }
    return out;
}

std::string jsonEscape(const std::string& text) {
    std::string out;
    for (char c : text) {
        if (c == '"' || c == '\\') { out += '\\'; out += c; }
        else out += c;
    }
    return out;
}

spektrafilm::Settings readSettings(JNIEnv* env, jstring stockId, jstring paperId,
                                   jfloatArray params) {
    spektrafilm::Settings settings;
    settings.stockId = toStd(env, stockId);
    settings.paperId = toStd(env, paperId);
    if (params != nullptr) {
        const jsize count = std::min<jsize>(env->GetArrayLength(params), 16);
        std::vector<float> values(static_cast<size_t>(count));
        env->GetFloatArrayRegion(params, 0, count, values.data());
        auto get = [&](int index, float fallback) {
            return index < static_cast<int>(values.size()) ? values[index] : fallback;
        };
        settings.scanFilm = get(0, 0) > 0.5f;
        settings.exposureEv = get(1, 0);
        settings.halationAmount = get(2, 1);
        settings.halationSpatialScale = get(3, 1);
        settings.grainStrength = get(4, 1);
        settings.particleAreaUm2 = get(5, 0.2f);
        settings.yFilterShift = get(6, 0);
        settings.mFilterShift = get(7, 0);
        settings.grain = get(8, 1) > 0.5f;
        settings.dirCouplers = get(9, 1) > 0.5f;
        settings.halation = get(10, 1) > 0.5f;
        settings.seed = static_cast<uint32_t>(get(11, 42));
    }
    return settings;
}

} // namespace

extern "C" JNIEXPORT jstring JNICALL
Java_com_zync_app_SpektrafilmBridge_nativeCatalog(JNIEnv* env, jclass, jstring dataDir) {
    try {
        const auto engine = engineFor(toStd(env, dataDir));
        std::ostringstream json;
        json << "{\"stocks\":[";
        bool first = true;
        for (const auto& stock : engine->stocks()) {
            if (!first) json << ',';
            first = false;
            json << "{\"id\":\"" << jsonEscape(stock.id) << "\",\"name\":\""
                 << jsonEscape(stock.name) << "\",\"targetPrint\":\""
                 << jsonEscape(stock.targetPrint) << "\",\"use\":\""
                 << jsonEscape(stock.use) << "\"}";
        }
        json << "],\"papers\":[";
        first = true;
        for (const auto& paper : engine->papers()) {
            if (!first) json << ',';
            first = false;
            json << "{\"id\":\"" << jsonEscape(paper.id) << "\",\"name\":\""
                 << jsonEscape(paper.name) << "\"}";
        }
        json << "]}";
        return env->NewStringUTF(json.str().c_str());
    } catch (const std::exception& error) {
        LOGE("catalog failed: %s", error.what());
        return env->NewStringUTF("{\"stocks\":[],\"papers\":[],\"error\":\"catalog\"}");
    }
}

extern "C" JNIEXPORT jbyteArray JNICALL
Java_com_zync_app_SpektrafilmBridge_nativeRender(
    JNIEnv* env, jclass, jstring dataDir, jstring stockId, jstring paperId,
    jfloatArray params, jbyteArray input, jint width, jint height) {
    try {
        const auto engine = engineFor(toStd(env, dataDir));
        const spektrafilm::Settings settings = readSettings(env, stockId, paperId, params);
        if (width <= 0 || height <= 0 || input == nullptr) return nullptr;
        const jsize length = env->GetArrayLength(input);
        if (length < width * height * 4) return nullptr;

        jbyte* bytes = env->GetByteArrayElements(input, nullptr);
        if (bytes == nullptr) return nullptr;
        const auto* rgba = reinterpret_cast<const uint8_t*>(bytes);

        const int fullWidth = width;
        const int fullHeight = height;
        const int outputLength = fullWidth * fullHeight * 4;
        std::vector<uint8_t> out(static_cast<size_t>(outputLength), 255);
        const float pixelSizeUm =
            35000.0f / static_cast<float>(std::max(fullWidth, fullHeight));
        constexpr int kTile = 1024;
        constexpr int kHalo = 64;

        for (int ty = 0; ty < fullHeight; ty += kTile) {
            for (int tx = 0; tx < fullWidth; tx += kTile) {
                const int x0 = std::max(0, tx - kHalo);
                const int y0 = std::max(0, ty - kHalo);
                const int x1 = std::min(fullWidth, tx + kTile + kHalo);
                const int y1 = std::min(fullHeight, ty + kTile + kHalo);
                const int tileWidth = x1 - x0;
                const int tileHeight = y1 - y0;
                spektrafilm::Image tile(tileWidth, tileHeight);
                for (int y = 0; y < tileHeight; ++y) {
                    for (int x = 0; x < tileWidth; ++x) {
                        const size_t i = (static_cast<size_t>(y0 + y) * fullWidth + (x0 + x)) * 4;
                        const spektrafilm::Vec3 srgb{
                            rgba[i] / 255.0f, rgba[i + 1] / 255.0f, rgba[i + 2] / 255.0f};
                        tile.at(x, y) = spektrafilm::Engine::srgbToProPhoto(srgb);
                    }
                }
                spektrafilm::Settings tileSettings = settings;
                tileSettings.pixelSizeUm = pixelSizeUm;
                tileSettings.grainOffsetX = x0;
                tileSettings.grainOffsetY = y0;
                tileSettings.seed = settings.seed;
                const auto rendered = engine->render(tile, tileSettings);

                const int cx0 = tx;
                const int cy0 = ty;
                const int cx1 = std::min(tx + kTile, fullWidth);
                const int cy1 = std::min(ty + kTile, fullHeight);
                for (int y = cy0; y < cy1; ++y) {
                    for (int x = cx0; x < cx1; ++x) {
                        const auto& value = rendered.at(x - x0, y - y0);
                        const size_t o = (static_cast<size_t>(y) * fullWidth + x) * 4;
                        out[o] = static_cast<uint8_t>(std::clamp(value.r, 0.0f, 1.0f) * 255.0f + 0.5f);
                        out[o + 1] = static_cast<uint8_t>(std::clamp(value.g, 0.0f, 1.0f) * 255.0f + 0.5f);
                        out[o + 2] = static_cast<uint8_t>(std::clamp(value.b, 0.0f, 1.0f) * 255.0f + 0.5f);
                        out[o + 3] = 255;
                    }
                }
            }
        }
        env->ReleaseByteArrayElements(input, bytes, JNI_ABORT);

        const jsize outLength = outputLength;
        jbyteArray result = env->NewByteArray(outLength);
        if (result == nullptr) return nullptr;
        env->SetByteArrayRegion(result, 0, outLength, reinterpret_cast<const jbyte*>(out.data()));
        return result;
    } catch (const std::exception& error) {
        LOGE("render failed: %s", error.what());
        return nullptr;
    } catch (...) {
        LOGE("render failed: unknown error");
        return nullptr;
    }
}

namespace {
void appendToVector(void* context, void* data, int size) {
    auto* output = static_cast<std::vector<unsigned char>*>(context);
    const auto* bytes = static_cast<unsigned char*>(data);
    output->insert(output->end(), bytes, bytes + size);
}
}

// Renders a LibRaw linear ProPhoto RGB 16-bit file (see
// RawProcessorBridge.nativeExtractLinear) and returns a JPEG.
extern "C" JNIEXPORT jbyteArray JNICALL
Java_com_zync_app_SpektrafilmBridge_nativeRenderRaw(
    JNIEnv* env, jclass, jstring dataDir, jstring stockId, jstring paperId,
    jfloatArray params, jstring linearPath, jint width, jint height,
    jint quality) {
    try {
        const auto engine = engineFor(toStd(env, dataDir));
        const spektrafilm::Settings settings = readSettings(env, stockId, paperId, params);
        const std::string path = toStd(env, linearPath);
        if (width <= 0 || height <= 0 || path.empty()) return nullptr;

        std::ifstream input(path, std::ios::binary);
        if (!input) return nullptr;
        input.seekg(0, std::ios::end);
        const auto fileSize = static_cast<size_t>(input.tellg());
        input.seekg(0, std::ios::beg);
        if (fileSize < static_cast<size_t>(width) * height * 6) return nullptr;

        const int fullWidth = width;
        const int fullHeight = height;
        std::vector<unsigned char> rgb(
            static_cast<size_t>(fullWidth) * fullHeight * 3, 0);
        const float pixelSizeUm =
            35000.0f / static_cast<float>(std::max(fullWidth, fullHeight));
        constexpr int kTile = 1024;
        constexpr int kHalo = 64;

        for (int ty = 0; ty < fullHeight; ty += kTile) {
            for (int tx = 0; tx < fullWidth; tx += kTile) {
                const int x0 = std::max(0, tx - kHalo);
                const int y0 = std::max(0, ty - kHalo);
                const int x1 = std::min(fullWidth, tx + kTile + kHalo);
                const int y1 = std::min(fullHeight, ty + kTile + kHalo);
                const int tileWidth = x1 - x0;
                const int tileHeight = y1 - y0;
                spektrafilm::Image tile(tileWidth, tileHeight);
                std::vector<uint16_t> row(static_cast<size_t>(fullWidth) * 3);
                for (int y = 0; y < tileHeight; ++y) {
                    const auto offset = static_cast<std::streamoff>(
                        (static_cast<size_t>(y0 + y) * fullWidth + x0) * 6);
                    input.seekg(offset, std::ios::beg);
                    input.read(reinterpret_cast<char*>(row.data()),
                               static_cast<std::streamsize>(tileWidth) * 6);
                    if (!input) return nullptr;
                    for (int x = 0; x < tileWidth; ++x) {
                        tile.at(x, y) = {
                            row[x * 3] / 65535.0f,
                            row[x * 3 + 1] / 65535.0f,
                            row[x * 3 + 2] / 65535.0f,
                        };
                    }
                }
                spektrafilm::Settings tileSettings = settings;
                tileSettings.pixelSizeUm = pixelSizeUm;
                tileSettings.grainOffsetX = x0;
                tileSettings.grainOffsetY = y0;
                const auto rendered = engine->render(tile, tileSettings);

                const int cx0 = tx;
                const int cy0 = ty;
                const int cx1 = std::min(tx + kTile, fullWidth);
                const int cy1 = std::min(ty + kTile, fullHeight);
                for (int y = cy0; y < cy1; ++y) {
                    for (int x = cx0; x < cx1; ++x) {
                        const auto& value = rendered.at(x - x0, y - y0);
                        const size_t o = (static_cast<size_t>(y) * fullWidth + x) * 3;
                        rgb[o] = static_cast<unsigned char>(std::clamp(value.r, 0.0f, 1.0f) * 255.0f + 0.5f);
                        rgb[o + 1] = static_cast<unsigned char>(std::clamp(value.g, 0.0f, 1.0f) * 255.0f + 0.5f);
                        rgb[o + 2] = static_cast<unsigned char>(std::clamp(value.b, 0.0f, 1.0f) * 255.0f + 0.5f);
                    }
                }
            }
        }

        std::vector<unsigned char> jpeg;
        jpeg.reserve(static_cast<size_t>(fullWidth) * fullHeight / 4 + 4096);
        const int q = quality > 0 ? std::clamp(quality, 1, 100) : 95;
        if (!stbi_write_jpg_to_func(appendToVector, &jpeg, fullWidth, fullHeight, 3,
                                    rgb.data(), q)) {
            return nullptr;
        }
        jbyteArray result = env->NewByteArray(static_cast<jsize>(jpeg.size()));
        if (result == nullptr) return nullptr;
        env->SetByteArrayRegion(result, 0, static_cast<jsize>(jpeg.size()),
                                reinterpret_cast<const jbyte*>(jpeg.data()));
        return result;
    } catch (const std::exception& error) {
        LOGE("renderRaw failed: %s", error.what());
        return nullptr;
    } catch (...) {
        LOGE("renderRaw failed: unknown error");
        return nullptr;
    }
}
