#include "style_resolver.h"
#include "entity_decoder.h"
#include <unordered_map>
#include <cctype>
#include <cstring>

namespace xmarkup {

// 标签名 → XMTagType 映射
static const std::unordered_map<std::string_view, int>& tag_map() {
    static const std::unordered_map<std::string_view, int> map = {
        // 文本样式
        {"b", XM_TAG_BOLD}, {"strong", XM_TAG_BOLD},
        {"i", XM_TAG_ITALIC}, {"em", XM_TAG_ITALIC},
        {"u", XM_TAG_UNDERLINE},
        {"s", XM_TAG_STRIKETHROUGH}, {"strike", XM_TAG_STRIKETHROUGH}, {"del", XM_TAG_STRIKETHROUGH},
        {"sub", XM_TAG_SUBSCRIPT}, {"sup", XM_TAG_SUPERSCRIPT},
        {"mark", XM_TAG_MARK},
        {"code", XM_TAG_CODE},
        // 段落结构
        {"p", XM_TAG_PARAGRAPH},
        {"h1", XM_TAG_HEADING_1}, {"h2", XM_TAG_HEADING_2},
        {"h3", XM_TAG_HEADING_3}, {"h4", XM_TAG_HEADING_4},
        {"h5", XM_TAG_HEADING_5}, {"h6", XM_TAG_HEADING_6},
        {"blockquote", XM_TAG_BLOCKQUOTE},
        {"pre", XM_TAG_PREFORMATTED},
        {"div", XM_TAG_DIVISION},
        {"span", XM_TAG_SPAN},
        // 链接与媒体
        {"a", XM_TAG_LINK},
        {"img", XM_TAG_IMAGE},
        {"video", XM_TAG_VIDEO},
        {"source", 0}, // 特殊处理：依赖父标签上下文
        {"audio", XM_TAG_AUDIO},
        // 列表
        {"ul", XM_TAG_LIST_UNORDERED}, {"ol", XM_TAG_LIST_ORDERED},
        {"li", XM_TAG_LIST_ITEM},
        // 表格
        {"table", XM_TAG_TABLE}, {"tr", XM_TAG_TABLE_ROW},
        {"td", XM_TAG_TABLE_CELL}, {"th", XM_TAG_TABLE_HEADER},
        // 其他
        {"hr", XM_TAG_HORIZONTAL_RULE}, {"br", XM_TAG_LINE_BREAK},
    };
    return map;
}

StyleResolver::StyleResolver(float base_font_size)
    : base_font_size_(base_font_size) {}

FlattenResult StyleResolver::resolve(const ASTNode& root) {
    result_.text.clear();
    result_.spans.clear();
    parent_stack_.clear();
    byte_offset_ = 0;
    dfs(root, false);
    return std::move(result_);
}

void StyleResolver::dfs(const ASTNode& node, bool inside_pre) {
    if (node.type == ASTNode::ROOT) {
        for (const auto& child : node.children) {
            dfs(child, inside_pre);
        }
        return;
    }

    if (node.type == ASTNode::TEXT) {
        // 解码 HTML 实体
        std::string decoded = EntityDecoder::decode(node.text);

        // 空白处理：非 pre 内折叠连续空白
        if (!inside_pre) {
            std::string collapsed;
            collapsed.reserve(decoded.size());
            bool prev_space = false;
            for (char c : decoded) {
                if (c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\f') {
                    if (!prev_space) {
                        collapsed += ' ';
                        prev_space = true;
                    }
                } else {
                    collapsed += c;
                    prev_space = false;
                }
            }
            decoded = std::move(collapsed);
        }

        if (!decoded.empty()) {
            result_.text += decoded;
            byte_offset_ += static_cast<uint32_t>(decoded.size());
        }
        return;
    }

    if (node.type == ASTNode::ELEMENT) {
        int tag_type = map_tag(node.tag_name);

        // 特殊处理：<source> 根据父标签栈判断上下文
        if (node.tag_name == "source") {
            for (auto it = parent_stack_.rbegin(); it != parent_stack_.rend(); ++it) {
                if (*it == "video") { tag_type = XM_TAG_VIDEO_SOURCE; break; }
                if (*it == "audio") { tag_type = XM_TAG_AUDIO_SOURCE; break; }
            }
        }

        // 记录 span 的起始位置
        uint32_t span_start = byte_offset_;

        // 先产出 span（保证外层在前，即 outside-in 顺序）
        size_t span_idx = result_.spans.size();
        std::string style_str;
        if (tag_type != 0) {
            InternalSpan span;
            span.byte_start = span_start;
            span.byte_end = span_start; // 临时值，处理完子节点后更新
            span.tag = tag_type;
            span.style = 0;

            // 提取特殊属性值
            if (tag_type == XM_TAG_LINK) {
                extract_attribute_value(node.attributes, "href", span.value);
            } else if (tag_type == XM_TAG_IMAGE) {
                extract_attribute_value(node.attributes, "src", span.value);
            } else if (tag_type == XM_TAG_VIDEO_SOURCE || tag_type == XM_TAG_AUDIO_SOURCE) {
                extract_attribute_value(node.attributes, "src", span.value);
            }

            // 提取 inline style（等子节点处理完再添加 style spans）
            extract_attribute_value(node.attributes, "style", style_str);

            result_.spans.push_back(std::move(span));
        }

        // 压入父标签栈
        parent_stack_.push_back(node.tag_name);

        // 递归处理子节点
        bool is_pre = inside_pre || (node.tag_name == "pre");
        for (const auto& child : node.children) {
            dfs(child, is_pre);
        }

        // 弹出父标签栈
        parent_stack_.pop_back();

        // 更新 byte_end 和添加 style spans
        if (tag_type != 0) {
            result_.spans[span_idx].byte_end = byte_offset_;
            if (!style_str.empty()) {
                add_style_spans(style_str, span_start, byte_offset_);
            }
        }
    }
}

void StyleResolver::add_style_spans(const std::string& style_str, uint32_t start, uint32_t end) {
    // 简单 CSS 行内样式解析：property:value; 分号分隔
    size_t pos = 0;
    while (pos < style_str.size()) {
        // 跳过空白
        while (pos < style_str.size() && isspace(static_cast<unsigned char>(style_str[pos]))) pos++;
        // 读取属性名
        size_t name_start = pos;
        while (pos < style_str.size() && style_str[pos] != ':') pos++;
        if (pos >= style_str.size()) break;
        std::string prop = style_str.substr(name_start, pos - name_start);
        // 去尾部空白
        while (!prop.empty() && isspace(static_cast<unsigned char>(prop.back()))) prop.pop_back();
        pos++; // 跳过 ':'
        // 跳过空白
        while (pos < style_str.size() && isspace(static_cast<unsigned char>(style_str[pos]))) pos++;
        // 读取属性值
        size_t val_start = pos;
        while (pos < style_str.size() && style_str[pos] != ';') pos++;
        std::string val = style_str.substr(val_start, pos - val_start);
        // 去尾部空白
        while (!val.empty() && isspace(static_cast<unsigned char>(val.back()))) val.pop_back();
        if (pos < style_str.size()) pos++; // 跳过 ';'

        // 映射属性名 → XMStyleType
        int style_type = 0;
        std::string normalized_value;

        if (prop == "color") {
            style_type = XM_STYLE_FOREGROUND_COLOR;
            normalized_value = normalize_color(val);
        } else if (prop == "background-color" || prop == "background") {
            style_type = XM_STYLE_BACKGROUND_COLOR;
            normalized_value = normalize_color(val);
        } else if (prop == "font-size") {
            style_type = XM_STYLE_FONT_SIZE;
            normalized_value = normalize_font_size(val);
        } else if (prop == "font-weight") {
            style_type = XM_STYLE_FONT_WEIGHT;
            normalized_value = normalize_font_weight(val);
        } else if (prop == "font-style") {
            style_type = XM_STYLE_FONT_STYLE;
            normalized_value = val;
        } else if (prop == "text-decoration") {
            style_type = XM_STYLE_TEXT_DECORATION;
            normalized_value = val;
        } else if (prop == "line-height") {
            style_type = XM_STYLE_LINE_HEIGHT;
            normalized_value = val;
        } else if (prop == "text-align") {
            style_type = XM_STYLE_TEXT_ALIGN;
            normalized_value = val;
        } else if (prop == "letter-spacing") {
            style_type = XM_STYLE_LETTER_SPACING;
            normalized_value = val;
        }

        if (style_type != 0 && !normalized_value.empty()) {
            InternalSpan span;
            span.byte_start = start;
            span.byte_end = end;
            span.tag = 0; // style span 没有关联标签
            span.style = style_type;
            span.value = std::move(normalized_value);
            result_.spans.push_back(std::move(span));
        }
    }
}

int StyleResolver::map_tag(std::string_view tag_name) const {
    const auto& map = tag_map();
    auto it = map.find(tag_name);
    return it != map.end() ? it->second : 0;
}

void StyleResolver::parse_inline_style(std::string_view) {
    // 已由 add_style_spans 处理，此方法保留为空
}

void StyleResolver::extract_attribute_value(std::string_view attrs, const char* attr_name,
                                             std::string& out_value) const {
    out_value.clear();
    if (attrs.empty()) return;

    size_t pos = 0;
    size_t name_len = std::strlen(attr_name);

    while (pos + name_len < attrs.size()) {
        // 查找属性名
        size_t found = attrs.find(attr_name, pos);
        if (found == std::string_view::npos) break;

        // 确认匹配的是完整单词（前面是空白或行首，后面是 = 或空白）
        if (found > 0 && !isspace(static_cast<unsigned char>(attrs[found - 1]))) {
            pos = found + 1;
            continue;
        }
        size_t after = found + name_len;
        if (after < attrs.size() && attrs[after] != '=' && !isspace(static_cast<unsigned char>(attrs[after]))) {
            pos = found + 1;
            continue;
        }

        // 找到了属性名，跳过空白和 '='
        size_t eq_pos = after;
        while (eq_pos < attrs.size() && isspace(static_cast<unsigned char>(attrs[eq_pos]))) eq_pos++;
        if (eq_pos >= attrs.size() || attrs[eq_pos] != '=') { pos = found + 1; continue; }
        eq_pos++; // 跳过 '='
        while (eq_pos < attrs.size() && isspace(static_cast<unsigned char>(attrs[eq_pos]))) eq_pos++;

        if (eq_pos >= attrs.size()) break;

        // 读取值
        if (attrs[eq_pos] == '"' || attrs[eq_pos] == '\'') {
            char quote = attrs[eq_pos];
            eq_pos++;
            size_t val_end = attrs.find(quote, eq_pos);
            if (val_end == std::string_view::npos) val_end = attrs.size();
            out_value = std::string(attrs.substr(eq_pos, val_end - eq_pos));
        } else {
            // 无引号值
            size_t val_end = eq_pos;
            while (val_end < attrs.size() && !isspace(static_cast<unsigned char>(attrs[val_end]))) val_end++;
            out_value = std::string(attrs.substr(eq_pos, val_end - eq_pos));
        }
        return;
    }
}

std::string StyleResolver::normalize_color(std::string_view value) const {
    if (value.empty()) return {};

    // 已经是 # 开头的 hex
    if (value[0] == '#') {
        std::string result(value);
        if (result.size() == 4) {
            // #RGB → #RRGGBB
            result = "#";
            result += value[1]; result += value[1];
            result += value[2]; result += value[2];
            result += value[3]; result += value[3];
        }
        // 转大写
        for (auto& c : result) { if (c >= 'a' && c <= 'f') c -= 32; }
        return result;
    }

    // rgb(r, g, b) 格式
    if (value.size() > 4 && value.substr(0, 4) == "rgb(") {
        // 简单解析 rgb 值
        size_t start = 4;
        int r = 0, g = 0, b = 0;
        auto parse_int = [&](size_t& p) -> int {
            int v = 0;
            while (p < value.size() && value[p] >= '0' && value[p] <= '9') {
                v = v * 10 + (value[p] - '0');
                p++;
            }
            return v;
        };
        r = parse_int(start);
        while (start < value.size() && (value[start] == ',' || value[start] == ' ')) start++;
        g = parse_int(start);
        while (start < value.size() && (value[start] == ',' || value[start] == ' ')) start++;
        b = parse_int(start);

        char buf[8];
        snprintf(buf, sizeof(buf), "#%02X%02X%02X", r, g, b);
        return buf;
    }

    // 颜色名称映射（常用颜色）
    static const std::unordered_map<std::string_view, const char*> color_names = {
        {"red", "#FF0000"}, {"green", "#008000"}, {"blue", "#0000FF"},
        {"black", "#000000"}, {"white", "#FFFFFF"}, {"yellow", "#FFFF00"},
        {"cyan", "#00FFFF"}, {"magenta", "#FF00FF"}, {"gray", "#808080"},
        {"grey", "#808080"}, {"orange", "#FFA500"}, {"purple", "#800080"},
        {"pink", "#FFC0CB"}, {"brown", "#A52A2A"}, {"navy", "#000080"},
        {"teal", "#008080"}, {"maroon", "#800000"}, {"olive", "#808000"},
        {"lime", "#00FF00"}, {"aqua", "#00FFFF"}, {"silver", "#C0C0C0"},
        {"gold", "#FFD700"}, {"indigo", "#4B0082"}, {"violet", "#EE82EE"},
        {"coral", "#FF7F50"}, {"salmon", "#FA8072"}, {"tomato", "#FF6347"},
        {"crimson", "#DC143C"}, {"darkred", "#8B0000"}, {"darkblue", "#00008B"},
        {"darkgreen", "#006400"}, {"darkgray", "#A9A9A9"}, {"lightgray", "#D3D3D3"},
    };
    std::string lower(value);
    for (auto& c : lower) { if (c >= 'A' && c <= 'Z') c += 32; }
    auto it = color_names.find(lower);
    if (it != color_names.end()) return it->second;

    return std::string(value);
}

std::string StyleResolver::normalize_font_size(std::string_view value) const {
    if (value.empty()) return {};

    // 提取数值部分
    double num = 0;
    size_t i = 0;
    bool has_dot = false;
    double frac = 0.1;
    while (i < value.size() && ((value[i] >= '0' && value[i] <= '9') || value[i] == '.')) {
        if (value[i] == '.') {
            has_dot = true;
        } else if (!has_dot) {
            num = num * 10 + (value[i] - '0');
        } else {
            num += (value[i] - '0') * frac;
            frac *= 0.1;
        }
        i++;
    }

    // 检查单位
    std::string unit;
    while (i < value.size() && isalpha(static_cast<unsigned char>(value[i]))) {
        unit += static_cast<char>(tolower(static_cast<unsigned char>(value[i])));
        i++;
    }

    // 换算为 px（保留浮点精度）
    double px = num;
    if (unit == "em") {
        px = num * base_font_size_;
    } else if (unit == "rem") {
        px = num * base_font_size_;
    } else if (unit == "pt") {
        px = num * 1.333; // 1pt ≈ 1.333px
    } else if (unit == "%") {
        px = num * base_font_size_ / 100.0;
    }
    // px 或无单位 → 直接用数值

    // 格式化：最多 2 位小数，去除尾部零
    char buf[32];
    std::snprintf(buf, sizeof(buf), "%.2f", px);
    std::string result(buf);
    // 去除尾部 '0'
    while (result.size() > 1 && result.back() == '0') result.pop_back();
    // 去除尾部 '.'
    if (result.size() > 1 && result.back() == '.') result.pop_back();
    return result;
}

std::string StyleResolver::normalize_font_weight(std::string_view value) const {
    // 直接返回值：normal/bold/100-900
    return std::string(value);
}

} // namespace xmarkup
