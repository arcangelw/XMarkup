#include "entity_decoder.h"
#include <unordered_map>
#include <cstdint>

namespace xmarkup {

// 命名实体映射表（常用 ~120 个）
static const std::unordered_map<std::string_view, const char*>& named_entities() {
    static const std::unordered_map<std::string_view, const char*> entities = {
        {"amp", "&"}, {"lt", "<"}, {"gt", ">"}, {"quot", "\""}, {"apos", "'"},
        {"nbsp", "\xC2\xA0"},
        {"copy", "\xC2\xA9"}, {"reg", "\xC2\xAE"}, {"trade", "\xE2\x84\xA2"},
        {"mdash", "\xE2\x80\x94"}, {"ndash", "\xE2\x80\x93"},
        {"laquo", "\xC2\xAB"}, {"raquo", "\xC2\xBB"},
        {"lsquo", "\xE2\x80\x98"}, {"rsquo", "\xE2\x80\x99"},
        {"ldquo", "\xE2\x80\x9C"}, {"rdquo", "\xE2\x80\x9D"},
        {"bull", "\xE2\x80\xA2"}, {"hellip", "\xE2\x80\xA6"},
        {"middot", "\xC2\xB7"}, {"para", "\xC2\xB6"}, {"sect", "\xC2\xA7"},
        {"deg", "\xC2\xB0"}, {"plusmn", "\xC2\xB1"},
        {"times", "\xC3\x97"}, {"divide", "\xC3\xB7"},
        {"frac12", "\xC2\xBD"}, {"frac14", "\xC2\xBC"}, {"frac34", "\xC2\xBE"},
        {"iexcl", "\xC2\xA1"}, {"iquest", "\xC2\xBF"},
        {"cent", "\xC2\xA2"}, {"pound", "\xC2\xA3"}, {"curren", "\xC2\xA4"},
        {"yen", "\xC2\xA5"}, {"euro", "\xE2\x82\xAC"},
        {"eacute", "\xC3\xA9"}, {"egrave", "\xC3\xA8"}, {"ecirc", "\xC3\xAA"},
        {"aacute", "\xC3\xA1"}, {"agrave", "\xC3\xA0"}, {"acirc", "\xC3\xA2"},
        {"uuml", "\xC3\xBC"}, {"uacute", "\xC3\xBA"}, {"ugrave", "\xC3\xB9"},
        {"ouml", "\xC3\xB6"}, {"oacute", "\xC3\xB3"}, {"ograve", "\xC3\xB2"},
        {"ocirc", "\xC3\xB4"}, {"oslash", "\xC3\xB8"},
        {"auml", "\xC3\xA4"}, {"iuml", "\xC3\xAF"},
        {"aring", "\xC3\xA5"}, {"aelig", "\xC3\xA6"},
        {"ccedil", "\xC3\xA7"}, {"ntilde", "\xC3\xB1"},
        {"szlig", "\xC3\x9F"},
        // 大写变体
        {"Agrave", "\xC3\x80"}, {"Aacute", "\xC3\x81"}, {"Acirc", "\xC3\x82"},
        {"Auml", "\xC3\x84"}, {"Aring", "\xC3\x85"}, {"AElig", "\xC3\x86"},
        {"Egrave", "\xC3\x88"}, {"Eacute", "\xC3\x89"}, {"Ecirc", "\xC3\x8A"},
        {"Igrave", "\xC3\x8C"}, {"Iacute", "\xC3\x8D"},
        {"Ograve", "\xC3\x92"}, {"Oacute", "\xC3\x93"}, {"Ocirc", "\xC3\x94"},
        {"Ouml", "\xC3\x96"}, {"Oslash", "\xC3\x98"},
        {"Ugrave", "\xC3\x99"}, {"Uacute", "\xC3\x9A"}, {"Uuml", "\xC3\x9C"},
        {"THORN", "\xC3\x9E"}, {"thorn", "\xC3\xBE"},
        {"ETH", "\xC3\x90"}, {"eth", "\xC3\xB0"},
        {"Yacute", "\xC3\x9D"}, {"yacute", "\xC3\xBD"}, {"yuml", "\xC3\xBF"},
        // 特殊符号
        {"larr", "\xE2\x86\x90"}, {"uarr", "\xE2\x86\x91"},
        {"rarr", "\xE2\x86\x92"}, {"darr", "\xE2\x86\x93"},
        {"harr", "\xE2\x86\x94"},
        {"lArr", "\xE2\x87\x90"}, {"uArr", "\xE2\x87\x91"},
        {"rArr", "\xE2\x87\x92"}, {"dArr", "\xE2\x87\x93"},
        {"hArr", "\xE2\x87\x94"},
        {"spades", "\xE2\x99\xA0"}, {"clubs", "\xE2\x99\xA3"},
        {"hearts", "\xE2\x99\xA5"}, {"diams", "\xE2\x99\xA6"},
        {"loz", "\xE2\x97\x8A"},
        {"ensp", "\xE2\x80\x82"}, {"emsp", "\xE2\x80\x83"}, {"thinsp", "\xE2\x80\x89"},
        {"zwnj", "\xE2\x80\x8C"}, {"zwj", "\xE2\x80\x8D"},
        {"lrm", "\xE2\x80\x8E"}, {"rlm", "\xE2\x80\x8F"},
        {"shy", "\xC2\xAD"},
        {"macr", "\xC2\xAF"}, {"acute", "\xC2\xB4"},
        {"micro", "\xC2\xB5"}, {"ordf", "\xC2\xAA"}, {"ordm", "\xC2\xBA"},
        {"sup1", "\xC2\xB9"}, {"sup2", "\xC2\xB2"}, {"sup3", "\xC2\xB3"},
        {"not", "\xC2\xAC"}, {"brvbar", "\xC2\xA6"}, {"cedil", "\xC2\xB8"},
        {"uml", "\xC2\xA8"}, {"circ", "\xCB\x86"}, {"tilde", "\xCB\x9C"},
        {"ring", "\xCB\x9A"}, {"cedil", "\xC2\xB8"},
        {"dagger", "\xE2\x80\xA0"}, {"Dagger", "\xE2\x80\xA1"},
        {"permil", "\xE2\x80\xB0"}, {"lsaquo", "\xE2\x80\xB9"}, {"rsaquo", "\xE2\x80\xBA"},
    };
    return entities;
}

// Unicode 码点到 UTF-8 编码
static std::string unicode_to_utf8(uint32_t cp) {
    std::string result;
    if (cp <= 0x7F) {
        result += static_cast<char>(cp);
    } else if (cp <= 0x7FF) {
        result += static_cast<char>(0xC0 | (cp >> 6));
        result += static_cast<char>(0x80 | (cp & 0x3F));
    } else if (cp <= 0xFFFF) {
        result += static_cast<char>(0xE0 | (cp >> 12));
        result += static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
        result += static_cast<char>(0x80 | (cp & 0x3F));
    } else if (cp <= 0x10FFFF) {
        result += static_cast<char>(0xF0 | (cp >> 18));
        result += static_cast<char>(0x80 | ((cp >> 12) & 0x3F));
        result += static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
        result += static_cast<char>(0x80 | (cp & 0x3F));
    }
    return result;
}

std::string EntityDecoder::decode(std::string_view text) {
    std::string result;
    result.reserve(text.size());

    size_t i = 0;
    while (i < text.size()) {
        if (text[i] == '&') {
            size_t entity_end = 0;
            std::string decoded;
            if (try_decode_entity(text, i, entity_end, decoded)) {
                result += decoded;
                i = entity_end;
                continue;
            }
        }
        result += text[i];
        i++;
    }
    return result;
}

bool EntityDecoder::try_decode_entity(std::string_view text, size_t pos,
                                       size_t& entity_end, std::string& decoded) {
    // text[pos] == '&'
    if (pos + 1 >= text.size()) return false;

    size_t start = pos + 1;

    // 查找 ';' 的位置，限制搜索范围（实体最长约 30 字符）
    size_t semi_pos = start;
    size_t limit = std::min(text.size(), start + 32);
    while (semi_pos < limit && text[semi_pos] != ';') {
        semi_pos++;
    }

    bool has_semi = (semi_pos < limit && text[semi_pos] == ';');

    if (has_semi) {
        // 提取实体名称（不含 & 和 ;）
        std::string_view entity = text.substr(start, semi_pos - start);
        if (entity.empty()) return false;

        // 尝试数字实体
        if (entity[0] == '#') {
            bool is_hex = (entity.size() > 1 && (entity[1] == 'x' || entity[1] == 'X'));
            std::string_view num_part = is_hex ? entity.substr(2) : entity.substr(1);
            if (num_part.empty()) return false;
            if (try_numeric_entity(num_part, is_hex, decoded)) {
                entity_end = semi_pos + 1;
                return true;
            }
            return false;
        }

        // 尝试命名实体
        if (try_named_entity(entity, decoded)) {
            entity_end = semi_pos + 1;
            return true;
        }

        // 未知命名实体，保留原始文本
        return false;
    }

    // 没有找到 ';'，容错：尝试将 & 后的字母序列匹配已知实体名
    size_t name_end = start;
    while (name_end < text.size() &&
           ((text[name_end] >= 'a' && text[name_end] <= 'z') ||
            (text[name_end] >= 'A' && text[name_end] <= 'Z'))) {
        name_end++;
    }
    // 从最长到最短尝试匹配
    for (size_t len = name_end - start; len > 0; len--) {
        std::string_view candidate = text.substr(start, len);
        if (try_named_entity(candidate, decoded)) {
            entity_end = start + len;
            return true;
        }
    }
    return false;
}

bool EntityDecoder::try_named_entity(std::string_view name, std::string& decoded) {
    const auto& entities = named_entities();
    auto it = entities.find(name);
    if (it != entities.end()) {
        decoded = it->second;
        return true;
    }
    return false;
}

bool EntityDecoder::try_numeric_entity(std::string_view value, bool is_hex,
                                        std::string& decoded) {
    uint32_t cp = 0;
    if (is_hex) {
        for (char c : value) {
            int digit;
            if (c >= '0' && c <= '9') digit = c - '0';
            else if (c >= 'a' && c <= 'f') digit = 10 + (c - 'a');
            else if (c >= 'A' && c <= 'F') digit = 10 + (c - 'A');
            else return false;
            cp = cp * 16 + static_cast<uint32_t>(digit);
            if (cp > 0x10FFFF) return false;
        }
    } else {
        for (char c : value) {
            if (c < '0' || c > '9') return false;
            cp = cp * 10 + static_cast<uint32_t>(c - '0');
            if (cp > 0x10FFFF) return false;
        }
    }

    // 替代字符和无效码点
    if (cp == 0 || (cp >= 0xD800 && cp <= 0xDFFF)) return false;

    decoded = unicode_to_utf8(cp);
    return !decoded.empty();
}

} // namespace xmarkup
