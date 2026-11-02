#pragma once

#include <charconv>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cmath>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <stdexcept>
#include <string>
#include <string_view>
#include <vector>

namespace spektrafilm {

inline std::string readText(const std::filesystem::path& path) {
    std::ifstream stream(path, std::ios::binary);
    if (!stream) throw std::runtime_error("Cannot open " + path.string());
    return {std::istreambuf_iterator<char>(stream), std::istreambuf_iterator<char>()};
}

class Json {
public:
    enum Type { Null, Boolean, Number, String, Array, Object };
    Type type = Null;
    bool boolean = false;
    double number = 0;
    std::string string;
    std::vector<Json> array;
    std::vector<std::pair<std::string, Json>> object;

    const Json& operator[](std::string_view key) const {
        for (const auto& [name, value] : object) {
            if (name == key) return value;
        }
        throw std::runtime_error("Missing JSON key: " + std::string(key));
    }
    bool has(std::string_view key) const {
        for (const auto& [name, value] : object) if (name == key) return true;
        return false;
    }
    const Json& at(size_t i) const { return array.at(i); }
    size_t size() const { return array.size(); }
    std::string asString(const std::string& fallback = "") const {
        return type == String ? string : fallback;
    }
    double asNumber(double fallback = 0) const {
        return type == Number ? number : fallback;
    }
};

class JsonParser {
public:
    explicit JsonParser(std::string_view source) : source_(source) {}
    Json parse() { Json result = value(); space(); return result; }
private:
    std::string_view source_;
    size_t offset_ = 0;
    void space() { while (offset_ < source_.size() && std::isspace(static_cast<unsigned char>(source_[offset_]))) ++offset_; }
    bool take(char c) { space(); if (offset_ < source_.size() && source_[offset_] == c) { ++offset_; return true; } return false; }
    char get() { if (offset_ >= source_.size()) throw std::runtime_error(std::string("Unexpected JSON end at ") + std::to_string(offset_)); return source_[offset_++]; }
    void expect(std::string_view text) { if (source_.substr(offset_, text.size()) != text) throw std::runtime_error("Invalid JSON token"); offset_ += text.size(); }
    Json value() {
        space();
        if (offset_ >= source_.size()) throw std::runtime_error(std::string("Unexpected JSON end at ") + std::to_string(offset_));
        const char c = source_[offset_];
        if (c == '{') return object();
        if (c == '[') return array();
        if (c == '"') { get(); Json j; j.type = Json::String; j.string = string(); return j; }
        if (c == 't') { expect("true"); Json j; j.type = Json::Boolean; j.boolean = true; return j; }
        if (c == 'f') { expect("false"); Json j; j.type = Json::Boolean; return j; }
        if (c == 'n') {
            expect("null");
            Json j; j.type = Json::Number; j.number = std::nan("");
            return j;
        }
        return number();
    }
    Json object() {
        Json j; j.type = Json::Object; get();
        if (take('}')) return j;
        do {
            space(); if (get() != '"') throw std::runtime_error("Expected JSON key");
            auto key = string(); if (!take(':')) throw std::runtime_error("Expected JSON colon");
            j.object.emplace_back(std::move(key), value());
        } while (take(','));
        if (!take('}')) throw std::runtime_error(std::string("Unclosed JSON object at ") + std::to_string(offset_) + " near " + std::string(source_.substr(offset_ > 30 ? offset_ - 30 : 0, 60)));
        return j;
    }
    Json array() {
        Json j; j.type = Json::Array; get();
        if (take(']')) return j;
        do { j.array.emplace_back(value()); } while (take(','));
        if (!take(']')) throw std::runtime_error(std::string("Unclosed JSON array at ") + std::to_string(offset_) + " near " + std::string(source_.substr(offset_ > 30 ? offset_ - 30 : 0, 60)));
        return j;
    }
    std::string string() {
        std::string out;
        while (true) {
            const char c = get();
            if (c == '"') break;
            if (c == '\\') {
                const char e = get();
                switch (e) {
                    case '"': out += '"'; break; case '\\': out += '\\'; break;
                    case '/': out += '/'; break; case 'b': out += '\b'; break;
                    case 'f': out += '\f'; break; case 'n': out += '\n'; break;
                    case 'r': out += '\r'; break; case 't': out += '\t'; break;
                    case 'u': {
                        unsigned code = 0;
                        for (int i = 0; i < 4; ++i) {
                            const char h = get();
                            code = code * 16 + (h <= '9' ? h - '0' : (h | 32) - 'a' + 10);
                        }
                        if (code < 0x80) out += static_cast<char>(code);
                        else if (code < 0x800) { out += static_cast<char>(0xC0 | code >> 6); out += static_cast<char>(0x80 | (code & 63)); }
                        else { out += static_cast<char>(0xE0 | code >> 12); out += static_cast<char>(0x80 | ((code >> 6) & 63)); out += static_cast<char>(0x80 | (code & 63)); }
                        break;
                    }
                    default: throw std::runtime_error("Invalid JSON escape");
                }
            } else out += c;
        }
        return out;
    }
    Json number() {
        const size_t begin = offset_;
        while (offset_ < source_.size() && std::string_view("-+.eE0123456789").find(source_[offset_]) != std::string_view::npos) ++offset_;
        Json j; j.type = Json::Number;
        const std::string token(source_.substr(begin, offset_ - begin));
        j.number = std::strtod(token.c_str(), nullptr);
        return j;
    }
};

inline Json parseJson(const std::string& text) { return JsonParser(text).parse(); }
inline std::vector<float> jsonFloats(const Json& json) {
    std::vector<float> result;
    result.reserve(json.size());
    for (const auto& v : json.array) result.push_back(static_cast<float>(v.number));
    return result;
}
inline std::vector<std::vector<float>> jsonFloatMatrix(const Json& json) {
    std::vector<std::vector<float>> result;
    result.reserve(json.size());
    for (const auto& row : json.array) result.push_back(jsonFloats(row));
    return result;
}

inline std::vector<float> readNpyFloat32(const std::filesystem::path& path) {
    std::ifstream stream(path, std::ios::binary);
    if (!stream) throw std::runtime_error("Cannot open NPY " + path.string());
    char magic[6]; stream.read(magic, 6);
    if (std::string(magic, 6) != "\x93NUMPY") throw std::runtime_error("Invalid NPY");
    uint8_t version[2]; stream.read(reinterpret_cast<char*>(version), 2);
    uint32_t headerSize = 0;
    if (version[0] == 1) { uint16_t size; stream.read(reinterpret_cast<char*>(&size), 2); headerSize = size; }
    else { stream.read(reinterpret_cast<char*>(&headerSize), 4); }
    std::string header(headerSize, '\0'); stream.read(header.data(), headerSize);
    if (header.find("'descr': '<f2'") == std::string::npos) throw std::runtime_error("Expected float16 NPY");
    const auto dims = header.find("'shape': (");
    const auto end = header.find(')', dims);
    const auto shape = header.substr(dims + 10, end - dims - 10);
    size_t count = 1, begin = 0;
    while (begin < shape.size()) {
        const auto comma = shape.find(',', begin);
        count *= static_cast<size_t>(std::stoul(shape.substr(begin, comma - begin)));
        if (comma == std::string::npos) break;
        begin = comma + 1;
    }
    std::vector<float> result(count);
    for (size_t i = 0; i < count; ++i) {
        uint16_t value; stream.read(reinterpret_cast<char*>(&value), 2);
        const uint32_t sign = (value & 0x8000u) << 16;
        int exponent = ((value >> 10) & 31) - 15;
        uint32_t mantissa = value & 1023;
        uint32_t bits;
        if (exponent == -15) {
            if (mantissa == 0) bits = sign;
            else {
                exponent = 0;
                while (!(mantissa & 1024)) { mantissa <<= 1; --exponent; }
                mantissa &= 1023;
                bits = sign | ((exponent + 127 - 10) << 23) | (mantissa << 13);
            }
        } else if (exponent == 16) bits = sign | 0x7f800000u | (mantissa << 13);
        else bits = sign | ((exponent + 127) << 23) | (mantissa << 13);
        float f; std::memcpy(&f, &bits, sizeof(f)); result[i] = f;
    }
    return result;
}

} // namespace spektrafilm
