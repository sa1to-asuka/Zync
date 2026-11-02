#pragma once

#include <algorithm>
#include <thread>
#include <vector>

#include "engine.hpp"

namespace spektrafilm {

template <typename Fn>
void parallelFor(int count, Fn&& fn) {
    if (count <= 0) return;
    const unsigned hardware = std::thread::hardware_concurrency();
    const int threads = std::min<int>(hardware == 0 ? 1 : static_cast<int>(hardware), 4);
    if (threads <= 1 || count < 32) {
        for (int i = 0; i < count; ++i) fn(i);
        return;
    }
    std::vector<std::thread> pool;
    pool.reserve(static_cast<size_t>(threads));
    for (int t = 0; t < threads; ++t) {
        const int begin = count * t / threads;
        const int end = count * (t + 1) / threads;
        pool.emplace_back([&fn, begin, end]() {
            for (int i = begin; i < end; ++i) fn(i);
        });
    }
    for (auto& worker : pool) worker.join();
}

void gaussian(Image& image, float sigmaPixels);
void gaussianRgb(Image& image, const Vec3& sigmaPixels);
void exponential(Image& image, float decayPixels);
void blurPlane(std::vector<float>& plane, int width, int height, float sigma);
void exponentialPlane(std::vector<float>& plane, int width, int height,
                      float decayPixels);
Vec3 interpolateDensity(const Vec3& logExposure, const Profile& profile,
                        float gamma = 1);
float normalCdf(float x);
float erfApprox(float x);

} // namespace spektrafilm
