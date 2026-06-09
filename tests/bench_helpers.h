#pragma once

#include <string>
#include <cstddef>

// ============================================================
// HTML 生成器 — 为 benchmark 生成各种模式的测试输入
// ============================================================

struct HtmlGenerator {
    /// 混合 HTML 模板段落（约 200 字节）
    static const char* mixed_template() {
        return
            "<p><b style=\"color:#ff0000\">Bold text 12345</b>"
            "<i>Italic text</i></p>"
            "<ul><li>Item A</li><li>Item B</li></ul>"
            "<a href=\"https://example.com/page\">Link text here</a>"
            "<table><tr><td>Cell A</td><td>Cell B</td></tr></table>"
            "<div><p>Nested paragraph with <b>bold</b> content</p></div>";
    }

    /// 生成指定大小的混合 HTML
    static std::string mixed(size_t target_bytes) {
        std::string result;
        result.reserve(target_bytes);
        const char* tmpl = mixed_template();
        size_t tmpl_len = std::char_traits<char>::length(tmpl);
        while (result.size() + tmpl_len <= target_bytes) {
            result += tmpl;
        }
        if (result.size() < target_bytes) {
            result.append(tmpl, target_bytes - result.size());
        }
        return result;
    }

    /// 纯文本，无标签 — 测试 tokenizer 的字符批量化效率
    static std::string pure_text(size_t target_bytes) {
        return std::string(target_bytes, 'A');
    }

    /// 密集嵌套标签 — 测试 TreeBuilder 栈操作效率
    static std::string heavy_tags(size_t target_bytes) {
        std::string result;
        result.reserve(target_bytes);
        const char* pattern = "<b><i><u>text</u></i></b>";
        size_t pat_len = std::char_traits<char>::length(pattern);
        while (result.size() + pat_len <= target_bytes) {
            result += pattern;
        }
        if (result.size() < target_bytes) {
            result.append(pattern, target_bytes - result.size());
        }
        return result;
    }

    /// 大量 CSS inline style — 测试 StyleResolver 解析效率
    static std::string heavy_style(size_t target_bytes) {
        std::string result;
        result.reserve(target_bytes);
        const char* pattern =
            "<span style=\"color:#ff0000;font-size:16px;font-weight:bold;"
            "text-align:center;line-height:1.5\">text</span>";
        size_t pat_len = std::char_traits<char>::length(pattern);
        while (result.size() + pat_len <= target_bytes) {
            result += pattern;
        }
        if (result.size() < target_bytes) {
            result.append(pattern, target_bytes - result.size());
        }
        return result;
    }

    /// 深层嵌套 — 测试栈深度性能
    static std::string deep_nesting(int depth) {
        std::string result;
        result.reserve(static_cast<size_t>(depth) * 10);
        for (int i = 0; i < depth; i++) {
            result += "<div>";
        }
        result += "text";
        for (int i = 0; i < depth; i++) {
            result += "</div>";
        }
        return result;
    }

    /// 大表格 — 测试隐式关闭在大规模表格中的开销
    static std::string wide_table(int rows, int cols) {
        std::string result = "<table>";
        for (int r = 0; r < rows; r++) {
            result += "<tr>";
            for (int c = 0; c < cols; c++) {
                result += "<td>Cell</td>";
            }
            result += "</tr>";
        }
        result += "</table>";
        return result;
    }

    /// 中英日韩 Emoji 混合 — 测试 UTF16Indexer 效率
    static std::string mixed_multilingual(size_t target_bytes) {
        const char* tmpl =
            "<p>Hello \xe4\xb8\x96\xe7\x95\x8c"
            "\xe3\x81\x93\xe3\x82\x93\xe3\x81\xab\xe3\x81\xa1\xe3\x81\xaf"
            "\xed\x95\x9c\xea\xb5\xad"
            "\xf0\x9f\x98\x8a\xf0\x9f\x8e\x89</p>";
        std::string result;
        result.reserve(target_bytes);
        size_t tmpl_len = std::char_traits<char>::length(tmpl);
        while (result.size() + tmpl_len <= target_bytes) {
            result += tmpl;
        }
        if (result.size() < target_bytes) {
            result.append(tmpl, target_bytes - result.size());
        }
        return result;
    }

    /// Adoption agency 测试模式：N 个 <b>text<p>para</p>
    static std::string adoption_pattern(int count) {
        std::string html = "<div>";
        html.reserve(static_cast<size_t>(count) * 30);
        for (int i = 0; i < count; i++) {
            html += "<b>text<p>para</p>";
        }
        html += "</div>";
        return html;
    }
};
