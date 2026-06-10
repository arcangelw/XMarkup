#pragma once

#include <string>
#include <cstddef>
#include <chrono>
#include <cstdint>

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

    /// 大量实体的 HTML（100 个 &amp;lt; 命名实体）
    static std::string heavy_entities(size_t target_bytes) {
        std::string result;
        result.reserve(target_bytes);
        const char* entity_block = "&amp;&lt;&gt;&quot;&apos;";
        size_t block_len = std::char_traits<char>::length(entity_block);
        while (result.size() + block_len <= target_bytes) {
            result += entity_block;
        }
        if (result.size() < target_bytes) {
            result.append(entity_block, target_bytes - result.size());
        }
        return result;
    }

    /// 极小 HTML（50 字节左右，测试固定开销）
    static std::string tiny_paragraph() {
        return "<p><b>Hi</b><i>!</i></p>";
    }
};

// ============================================================
// 分阶段计时器 — 测量各管线阶段耗时
// ============================================================

#include "tokenizer.h"
#include "tree_builder.h"
#include "style_resolver.h"
#include "utf16_indexer.h"

struct StageTimer {
    uint64_t tokenizer_us;
    uint64_t tree_builder_us;
    uint64_t style_resolver_us;
    uint64_t utf16_indexer_us;
    uint64_t total_us;

    using Clock = std::chrono::high_resolution_clock;
    using TimePoint = std::chrono::time_point<Clock>;

    static uint64_t us_between(TimePoint start, TimePoint end) {
        return static_cast<uint64_t>(
            std::chrono::duration_cast<std::chrono::microseconds>(end - start).count());
    }

    static StageTimer measure(const char* html, size_t length, const XMConfig& cfg) {
        StageTimer t{};
        TimePoint t0, t1, t2, t3, t4;

        // 阶段 1：词法分析
        t0 = Clock::now();
        std::string_view html_view(html, length);
        xmarkup::Tokenizer tokenizer(html_view);
        std::vector<xmarkup::Token> tokens;
        while (tokenizer.has_next()) tokens.push_back(tokenizer.next());
        t1 = Clock::now();

        // 阶段 2：AST 构建
        xmarkup::TreeBuilder tree_builder(cfg.max_nesting_depth, cfg.enable_autocorrect);
        xmarkup::ASTNode ast = tree_builder.build(tokens);
        t2 = Clock::now();

        // 阶段 3：样式解析
        xmarkup::StyleResolver style_resolver(cfg.base_font_size);
        xmarkup::FlattenResult flat = style_resolver.resolve(ast);
        t3 = Clock::now();

        // 阶段 4：UTF-16 映射
        xmarkup::UTF16Indexer indexer;
        indexer.build(flat.text);
        t4 = Clock::now();

        t.tokenizer_us     = us_between(t0, t1);
        t.tree_builder_us  = us_between(t1, t2);
        t.style_resolver_us = us_between(t2, t3);
        t.utf16_indexer_us = us_between(t3, t4);
        t.total_us         = us_between(t0, t4);
        return t;
    }
};

// ============================================================
// 内存追踪器 — 测量解析过程内存增量
// ============================================================

#ifdef __APPLE__
#include <mach/mach.h>
#elif defined(__linux__)
#include <fstream>
#endif

struct MemoryTracker {
    size_t peak_rss_kb;
    size_t delta_rss_kb;

    static size_t get_rss_kb() {
#ifdef __APPLE__
        struct mach_task_basic_info info;
        mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
        if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO,
                      (thread_info_t)&info, &count) == KERN_SUCCESS) {
            return info.resident_size / 1024;
        }
        return 0;
#elif defined(__linux__)
        std::ifstream ifs("/proc/self/status");
        std::string line;
        while (std::getline(ifs, line)) {
            if (line.compare(0, 6, "VmRSS:") == 0) {
                return std::stoul(line.substr(6));
            }
        }
        return 0;
#else
        return 0;
#endif
    }

    static MemoryTracker snapshot() {
        MemoryTracker mt;
        mt.peak_rss_kb = get_rss_kb();
        mt.delta_rss_kb = 0;
        return mt;
    }

    static MemoryTracker measure_parsing(const char* html, size_t length, const XMConfig& cfg) {
        size_t before = get_rss_kb();
        XMParser* p = xmarkup_create(&cfg);
        XMResult* r = xmarkup_parse(p, html, length);
        size_t after = get_rss_kb();
        xmarkup_result_free(r);
        xmarkup_destroy(p);
        MemoryTracker mt;
        mt.peak_rss_kb = after;
        mt.delta_rss_kb = (after > before) ? (after - before) : 0;
        return mt;
    }
};
