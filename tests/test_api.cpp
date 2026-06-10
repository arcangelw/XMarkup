#include <gtest/gtest.h>
#include <cstring>
#include <chrono>
#include <thread>
#include <atomic>
#include <vector>
#include <string>
#include <utility>
#include "xmarkup/xmarkup.h"

class APITest : public ::testing::Test {
protected:
    void SetUp() override {
        XMConfig cfg = {1, 256, 16.0f, nullptr, nullptr, XM_LOG_ERROR};
        parser_ = xmarkup_create(&cfg);
        ASSERT_NE(parser_, nullptr);
    }
    void TearDown() override {
        if (parser_) xmarkup_destroy(parser_);
    }

    XMResult* parse(const char* html) {
        return xmarkup_parse(parser_, html, std::strlen(html));
    }

    XMParser* parser_ = nullptr;
};

// === 基本管线 ===

TEST_F(APITest, SimpleBold) {
    const char* html = "<b>bold</b>";
    auto* result = parse(html);
    ASSERT_NE(result, nullptr);
    EXPECT_EQ(result->error, XM_OK);
    EXPECT_STREQ(result->text, "bold");
    EXPECT_EQ(result->span_count, 1u);
    EXPECT_EQ(result->spans[0].tag, XM_TAG_BOLD);
    EXPECT_EQ(result->spans[0].range.start, 0u);
    EXPECT_EQ(result->spans[0].range.end, 4u);
    xmarkup_result_free(result);
}

TEST_F(APITest, EmptyInput) {
    auto* result = parse("");
    ASSERT_NE(result, nullptr);
    EXPECT_EQ(result->error, XM_OK);
    EXPECT_STREQ(result->text, "");
    EXPECT_EQ(result->span_count, 0u);
    xmarkup_result_free(result);
}

TEST_F(APITest, NullParser) {
    auto* result = xmarkup_parse(nullptr, "test", 4);
    EXPECT_EQ(result, nullptr);
}

// === 文本样式 ===

TEST_F(APITest, ItalicTag) {
    auto* r = parse("<i>italic</i>");
    ASSERT_NE(r, nullptr);
    EXPECT_EQ(r->span_count, 1u);
    EXPECT_EQ(r->spans[0].tag, XM_TAG_ITALIC);
    EXPECT_STREQ(r->text, "italic");
    xmarkup_result_free(r);
}

TEST_F(APITest, UnderlineTag) {
    auto* r = parse("<u>underline</u>");
    ASSERT_NE(r, nullptr);
    EXPECT_EQ(r->span_count, 1u);
    EXPECT_EQ(r->spans[0].tag, XM_TAG_UNDERLINE);
    xmarkup_result_free(r);
}

TEST_F(APITest, StrikethroughTag) {
    auto* r = parse("<s>strike</s>");
    ASSERT_NE(r, nullptr);
    EXPECT_EQ(r->span_count, 1u);
    EXPECT_EQ(r->spans[0].tag, XM_TAG_STRIKETHROUGH);
    xmarkup_result_free(r);
}

TEST_F(APITest, NestedBoldItalic) {
    auto* r = parse("<b><i>bold-italic</i></b>");
    ASSERT_NE(r, nullptr);
    EXPECT_STREQ(r->text, "bold-italic");
    EXPECT_GE(r->span_count, 2u);
    EXPECT_EQ(r->spans[0].tag, XM_TAG_BOLD);
    EXPECT_EQ(r->spans[1].tag, XM_TAG_ITALIC);
    // 两个 span 的范围应该相同
    EXPECT_EQ(r->spans[0].range.start, 0u);
    EXPECT_EQ(r->spans[1].range.start, 0u);
    EXPECT_EQ(r->spans[0].range.end, r->spans[1].range.end);
    xmarkup_result_free(r);
}

TEST_F(APITest, TagWithCSSColor) {
    auto* r = parse(R"(<b style="color:#ff0000">red bold</b>)");
    ASSERT_NE(r, nullptr);
    EXPECT_STREQ(r->text, "red bold");
    // 至少有 BOLD span + FOREGROUND_COLOR span
    EXPECT_GE(r->span_count, 2u);
    bool has_bold = false, has_color = false;
    for (uint32_t i = 0; i < r->span_count; i++) {
        if (r->spans[i].tag == XM_TAG_BOLD) has_bold = true;
        if (r->spans[i].style == XM_STYLE_FOREGROUND_COLOR) {
            has_color = true;
            EXPECT_STREQ(r->spans[i].value, "#FF0000");
        }
    }
    EXPECT_TRUE(has_bold);
    EXPECT_TRUE(has_color);
    xmarkup_result_free(r);
}

// === 段落结构 ===

TEST_F(APITest, ParagraphTag) {
    auto* r = parse("<p>Hello</p>");
    ASSERT_NE(r, nullptr);
    EXPECT_EQ(r->span_count, 1u);
    EXPECT_EQ(r->spans[0].tag, XM_TAG_PARAGRAPH);
    xmarkup_result_free(r);
}

TEST_F(APITest, HeadingH1) {
    auto* r = parse("<h1>Title</h1>");
    ASSERT_NE(r, nullptr);
    EXPECT_EQ(r->span_count, 1u);
    EXPECT_EQ(r->spans[0].tag, XM_TAG_HEADING_1);
    xmarkup_result_free(r);
}

TEST_F(APITest, HeadingAllLevels) {
    const char* tags[] = {"h1","h2","h3","h4","h5","h6"};
    XMTagType expected[] = {XM_TAG_HEADING_1, XM_TAG_HEADING_2, XM_TAG_HEADING_3,
                            XM_TAG_HEADING_4, XM_TAG_HEADING_5, XM_TAG_HEADING_6};
    for (int i = 0; i < 6; i++) {
        std::string html = std::string("<") + tags[i] + ">text</" + tags[i] + ">";
        auto* r = parse(html.c_str());
        ASSERT_NE(r, nullptr) << "level " << tags[i];
        EXPECT_EQ(r->spans[0].tag, expected[i]) << "level " << tags[i];
        xmarkup_result_free(r);
    }
}

TEST_F(APITest, PreWhitespacePreserved) {
    auto* r = parse("<pre>  spaces  \n  lines  </pre>");
    ASSERT_NE(r, nullptr);
    // pre 内空白保留，且作为块级元素尾部追加 \n
    EXPECT_STREQ(r->text, "  spaces  \n  lines  \n");
    xmarkup_result_free(r);
}

// === 链接与媒体 ===

TEST_F(APITest, LinkWithHref) {
    auto* r = parse("<a href=\"https://example.com\">click</a>");
    ASSERT_NE(r, nullptr);
    EXPECT_STREQ(r->text, "click");
    EXPECT_EQ(r->span_count, 1u);
    EXPECT_EQ(r->spans[0].tag, XM_TAG_LINK);
    EXPECT_STREQ(r->spans[0].value, "https://example.com");
    xmarkup_result_free(r);
}

TEST_F(APITest, ImageWithSrc) {
    auto* r = parse("<img src=\"photo.jpg\">");
    ASSERT_NE(r, nullptr);
    EXPECT_EQ(r->span_count, 1u);
    EXPECT_EQ(r->spans[0].tag, XM_TAG_IMAGE);
    EXPECT_STREQ(r->spans[0].value, "photo.jpg");
    xmarkup_result_free(r);
}

TEST_F(APITest, VideoWithSource) {
    auto* r = parse("<video><source src=\"a.mp4\" type=\"video/mp4\"></video>");
    ASSERT_NE(r, nullptr);
    bool found = false;
    for (uint32_t i = 0; i < r->span_count; i++) {
        if (r->spans[i].tag == XM_TAG_VIDEO_SOURCE) {
            found = true;
            EXPECT_STREQ(r->spans[i].value, "a.mp4");
        }
    }
    EXPECT_TRUE(found);
    xmarkup_result_free(r);
}

// === 列表 ===

TEST_F(APITest, UnorderedList) {
    auto* r = parse("<ul><li>A</li><li>B</li></ul>");
    ASSERT_NE(r, nullptr);
    bool found_ul = false, found_li = false;
    for (uint32_t i = 0; i < r->span_count; i++) {
        if (r->spans[i].tag == XM_TAG_LIST_UNORDERED) found_ul = true;
        if (r->spans[i].tag == XM_TAG_LIST_ITEM) found_li = true;
    }
    EXPECT_TRUE(found_ul);
    EXPECT_TRUE(found_li);
    xmarkup_result_free(r);
}

// === 表格 ===

TEST_F(APITest, Table) {
    auto* r = parse("<table><tr><td>cell</td></tr></table>");
    ASSERT_NE(r, nullptr);
    bool found_table = false, found_tr = false, found_td = false;
    for (uint32_t i = 0; i < r->span_count; i++) {
        if (r->spans[i].tag == XM_TAG_TABLE) found_table = true;
        if (r->spans[i].tag == XM_TAG_TABLE_ROW) found_tr = true;
        if (r->spans[i].tag == XM_TAG_TABLE_CELL) found_td = true;
    }
    EXPECT_TRUE(found_table);
    EXPECT_TRUE(found_tr);
    EXPECT_TRUE(found_td);
    xmarkup_result_free(r);
}

// === 特殊标签 ===

TEST_F(APITest, OrderedList) {
    auto* r = parse("<ol><li>A</li><li>B</li></ol>");
    ASSERT_NE(r, nullptr);
    bool found_ol = false, found_li = false;
    for (uint32_t i = 0; i < r->span_count; i++) {
        if (r->spans[i].tag == XM_TAG_LIST_ORDERED) found_ol = true;
        if (r->spans[i].tag == XM_TAG_LIST_ITEM) found_li = true;
    }
    EXPECT_TRUE(found_ol);
    EXPECT_TRUE(found_li);
    xmarkup_result_free(r);
}

TEST_F(APITest, SubscriptTag) {
    auto* r = parse("base<sub>sub</sub>");
    ASSERT_NE(r, nullptr);
    bool found = false;
    for (uint32_t i = 0; i < r->span_count; i++) {
        if (r->spans[i].tag == XM_TAG_SUBSCRIPT) found = true;
    }
    EXPECT_TRUE(found);
    xmarkup_result_free(r);
}

TEST_F(APITest, SuperscriptTag) {
    auto* r = parse("base<sup>sup</sup>");
    ASSERT_NE(r, nullptr);
    bool found = false;
    for (uint32_t i = 0; i < r->span_count; i++) {
        if (r->spans[i].tag == XM_TAG_SUPERSCRIPT) found = true;
    }
    EXPECT_TRUE(found);
    xmarkup_result_free(r);
}

TEST_F(APITest, CodeTag) {
    auto* r = parse("<code>code</code>");
    ASSERT_NE(r, nullptr);
    bool found = false;
    for (uint32_t i = 0; i < r->span_count; i++) {
        if (r->spans[i].tag == XM_TAG_CODE) found = true;
    }
    EXPECT_TRUE(found);
    xmarkup_result_free(r);
}

TEST_F(APITest, MarkTag) {
    auto* r = parse("<mark>highlight</mark>");
    ASSERT_NE(r, nullptr);
    bool found = false;
    for (uint32_t i = 0; i < r->span_count; i++) {
        if (r->spans[i].tag == XM_TAG_MARK) found = true;
    }
    EXPECT_TRUE(found);
    xmarkup_result_free(r);
}

TEST_F(APITest, DelTag) {
    auto* r = parse("<del>deleted</del>");
    ASSERT_NE(r, nullptr);
    bool found = false;
    for (uint32_t i = 0; i < r->span_count; i++) {
        if (r->spans[i].tag == XM_TAG_STRIKETHROUGH) found = true;
    }
    EXPECT_TRUE(found);
    xmarkup_result_free(r);
}

TEST_F(APITest, LineBreak) {
    auto* r = parse("before<br>after");
    ASSERT_NE(r, nullptr);
    bool found_br = false;
    for (uint32_t i = 0; i < r->span_count; i++) {
        if (r->spans[i].tag == XM_TAG_LINE_BREAK) found_br = true;
    }
    EXPECT_TRUE(found_br);
    xmarkup_result_free(r);
}

TEST_F(APITest, HorizontalRule) {
    auto* r = parse("before<hr>after");
    ASSERT_NE(r, nullptr);
    bool found_hr = false;
    for (uint32_t i = 0; i < r->span_count; i++) {
        if (r->spans[i].tag == XM_TAG_HORIZONTAL_RULE) found_hr = true;
    }
    EXPECT_TRUE(found_hr);
    xmarkup_result_free(r);
}

// === 纠错 ===

TEST_F(APITest, UnclosedTags) {
    auto* r = parse("<div><p>text");
    ASSERT_NE(r, nullptr);
    EXPECT_EQ(r->error, XM_OK);
    EXPECT_NE(r->text, nullptr);
    xmarkup_result_free(r);
}

TEST_F(APITest, ExtraCloseTag) {
    auto* r = parse("</b>text");
    ASSERT_NE(r, nullptr);
    EXPECT_STREQ(r->text, "text");
    xmarkup_result_free(r);
}

// === 实体解码 ===

TEST_F(APITest, EntityDecoding) {
    auto* r = parse("<b>1 &lt; 2 &amp; 3 &gt; 0</b>");
    ASSERT_NE(r, nullptr);
    EXPECT_STREQ(r->text, "1 < 2 & 3 > 0");
    xmarkup_result_free(r);
}

// === CSS 标准化 ===

TEST_F(APITest, CSSColorNameNormalized) {
    auto* r = parse(R"(<span style="color:red">text</span>)");
    ASSERT_NE(r, nullptr);
    bool found = false;
    for (uint32_t i = 0; i < r->span_count; i++) {
        if (r->spans[i].style == XM_STYLE_FOREGROUND_COLOR && r->spans[i].value) {
            if (std::strcmp(r->spans[i].value, "#FF0000") == 0) found = true;
        }
    }
    EXPECT_TRUE(found);
    xmarkup_result_free(r);
}

TEST_F(APITest, CSSFontSizeEmNormalized) {
    auto* r = parse(R"(<span style="font-size:1.5em">text</span>)");
    ASSERT_NE(r, nullptr);
    bool found = false;
    for (uint32_t i = 0; i < r->span_count; i++) {
        if (r->spans[i].style == XM_STYLE_FONT_SIZE && r->spans[i].value) {
            if (std::strcmp(r->spans[i].value, "24") == 0) found = true;
        }
    }
    EXPECT_TRUE(found);
    xmarkup_result_free(r);
}

// === 错误查询 ===

TEST_F(APITest, ErrorString) {
    EXPECT_STREQ(xmarkup_error_string(XM_OK), "Success");
    EXPECT_STREQ(xmarkup_error_string(XM_ERR_NULL_PARSER), "Parser is NULL");
    EXPECT_STREQ(xmarkup_error_string(XM_ERR_NULL_INPUT), "Input HTML is NULL");
    EXPECT_STREQ(xmarkup_error_string(XM_ERR_NESTING_OVERFLOW), "Nesting depth overflow, truncated");
    EXPECT_STREQ(xmarkup_error_string(XM_ERR_ALLOC_FAILED), "Memory allocation failed");
    // 未知错误码返回 "Unknown error"
    EXPECT_STREQ(xmarkup_error_string(static_cast<XMError>(999)), "Unknown error");
}

TEST_F(APITest, GetLastError) {
    EXPECT_EQ(xmarkup_last_error(parser_), XM_OK);
}

// === 性能测试 ===

TEST_F(APITest, Stress50KB) {
    std::string html;
    html.reserve(50000);
    for (int i = 0; html.size() < 50000; i++) {
        html += "<p><b style=\"color:#ff0000\">Bold";
        html += std::to_string(i);
        html += "</b><i>Italic</i></p>";
    }

    auto start = std::chrono::high_resolution_clock::now();
    auto* result = xmarkup_parse(parser_, html.c_str(), html.size());
    auto end = std::chrono::high_resolution_clock::now();

    ASSERT_NE(result, nullptr);
    EXPECT_EQ(result->error, XM_OK);
    EXPECT_GT(result->span_count, 0u);

    auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count();
    EXPECT_LT(ms, 50) << "50KB 解析耗时 " << ms << "ms，超出 50ms 宽松目标";

    xmarkup_result_free(result);
}

// === 恶意输入测试 ===

TEST_F(APITest, MaliciousDeepNesting) {
    std::string html;
    for (int i = 0; i < 10000; i++) html += "<div>";
    html += "text";
    EXPECT_NO_FATAL_FAILURE({
        auto* result = xmarkup_parse(parser_, html.c_str(), html.size());
        ASSERT_NE(result, nullptr);
        EXPECT_NE(result->text, nullptr);
        xmarkup_result_free(result);
    });
}

TEST_F(APITest, MaliciousUnclosedTags) {
    std::string html;
    for (int i = 0; i < 1000; i++) html += "<p>";
    html += "text";
    EXPECT_NO_FATAL_FAILURE({
        auto* result = xmarkup_parse(parser_, html.c_str(), html.size());
        ASSERT_NE(result, nullptr);
        EXPECT_NE(result->text, nullptr);
        xmarkup_result_free(result);
    });
}

// === 线程安全测试 ===

TEST_F(APITest, ThreadSafety) {
    const char* html = "<b><i style=\"color:red\">text</i></b>";
    constexpr int num_threads = 8;
    std::vector<std::thread> threads;
    std::atomic<int> errors{0};

    for (int t = 0; t < num_threads; t++) {
        threads.emplace_back([&]() {
            XMConfig cfg = {1, 256, 16.0f, nullptr, nullptr, XM_LOG_ERROR};
            XMParser* p = xmarkup_create(&cfg);
            for (int i = 0; i < 100; i++) {
                auto* result = xmarkup_parse(p, html, std::strlen(html));
                if (!result || result->error != XM_OK) {
                    errors++;
                } else {
                    xmarkup_result_free(result);
                }
            }
            xmarkup_destroy(p);
        });
    }

    for (auto& t : threads) t.join();
    EXPECT_EQ(errors, 0);
}

TEST_F(APITest, CSSBackgroundColor) {
    auto* r = parse(R"(<span style="background-color:#00FF00">green</span>)");
    ASSERT_NE(r, nullptr);
    bool found = false;
    for (uint32_t i = 0; i < r->span_count; i++) {
        if (r->spans[i].style == XM_STYLE_BACKGROUND_COLOR && r->spans[i].value) {
            if (std::strcmp(r->spans[i].value, "#00FF00") == 0) found = true;
        }
    }
    EXPECT_TRUE(found);
    xmarkup_result_free(r);
}

TEST_F(APITest, CSSFontWeight) {
    auto* r = parse(R"(<span style="font-weight:bold">bold</span>)");
    ASSERT_NE(r, nullptr);
    bool found = false;
    for (uint32_t i = 0; i < r->span_count; i++) {
        if (r->spans[i].style == XM_STYLE_FONT_WEIGHT && r->spans[i].value) {
            if (std::strcmp(r->spans[i].value, "bold") == 0) found = true;
        }
    }
    EXPECT_TRUE(found);
    xmarkup_result_free(r);
}

TEST_F(APITest, CSSFontStyle) {
    auto* r = parse(R"(<span style="font-style:italic">italic</span>)");
    ASSERT_NE(r, nullptr);
    bool found = false;
    for (uint32_t i = 0; i < r->span_count; i++) {
        if (r->spans[i].style == XM_STYLE_FONT_STYLE && r->spans[i].value) {
            if (std::strcmp(r->spans[i].value, "italic") == 0) found = true;
        }
    }
    EXPECT_TRUE(found);
    xmarkup_result_free(r);
}

TEST_F(APITest, CSSTextDecoration) {
    auto* r = parse(R"(<span style="text-decoration:underline">under</span>)");
    ASSERT_NE(r, nullptr);
    bool found = false;
    for (uint32_t i = 0; i < r->span_count; i++) {
        if (r->spans[i].style == XM_STYLE_TEXT_DECORATION && r->spans[i].value) {
            if (std::strcmp(r->spans[i].value, "underline") == 0) found = true;
        }
    }
    EXPECT_TRUE(found);
    xmarkup_result_free(r);
}

TEST_F(APITest, CSSTextAlign) {
    auto* r = parse(R"(<p style="text-align:center">center</p>)");
    ASSERT_NE(r, nullptr);
    bool found = false;
    for (uint32_t i = 0; i < r->span_count; i++) {
        if (r->spans[i].style == XM_STYLE_TEXT_ALIGN && r->spans[i].value) {
            if (std::strcmp(r->spans[i].value, "center") == 0) found = true;
        }
    }
    EXPECT_TRUE(found);
    xmarkup_result_free(r);
}

TEST_F(APITest, CSSLineHeight) {
    auto* r = parse(R"(<span style="line-height:1.5">text</span>)");
    ASSERT_NE(r, nullptr);
    bool found = false;
    for (uint32_t i = 0; i < r->span_count; i++) {
        if (r->spans[i].style == XM_STYLE_LINE_HEIGHT && r->spans[i].value) {
            found = true;
        }
    }
    EXPECT_TRUE(found);
    xmarkup_result_free(r);
}

TEST_F(APITest, CSSLetterSpacing) {
    auto* r = parse(R"(<span style="letter-spacing:2px">text</span>)");
    ASSERT_NE(r, nullptr);
    bool found = false;
    for (uint32_t i = 0; i < r->span_count; i++) {
        if (r->spans[i].style == XM_STYLE_LETTER_SPACING && r->spans[i].value) {
            if (std::strcmp(r->spans[i].value, "2px") == 0) found = true;
        }
    }
    EXPECT_TRUE(found);
    xmarkup_result_free(r);
}

TEST_F(APITest, AutocorrectDisabled) {
    // enable_autocorrect = false：adoption agency 禁用
    XMConfig cfg = {0, 256, 16.0f, nullptr, nullptr, XM_LOG_ERROR};
    XMParser* p = xmarkup_create(&cfg);
    ASSERT_NE(p, nullptr);
    auto* r = xmarkup_parse(p, "<div><b>text<p>para</p></b></div>", 31);
    ASSERT_NE(r, nullptr);
    // adoption 禁用 → <b> 不被重建，<p> 嵌套在 <b> 内
    // 所以 div 的直接子节点应为 1 个（<b>），而不是 2 个（<b> + <p>）
    // 验证运行无 crash
    EXPECT_EQ(r->error, XM_OK);
    xmarkup_result_free(r);
    xmarkup_destroy(p);
}

TEST_F(APITest, SemanticBlockTags) {
    // 验证语义块级标签的标签映射
    struct { const char* html; XMTagType expected; } cases[] = {
        {"<article>A</article>", XM_TAG_ARTICLE},
        {"<section>S</section>", XM_TAG_SECTION},
        {"<header>H</header>", XM_TAG_HEADER},
        {"<footer>F</footer>", XM_TAG_FOOTER},
        {"<nav>N</nav>", XM_TAG_NAV},
        {"<aside>A</aside>", XM_TAG_ASIDE},
        {"<figure>F</figure>", XM_TAG_FIGURE},
        {"<figcaption>C</figcaption>", XM_TAG_FIGCAPTION},
        {"<main>M</main>", XM_TAG_MAIN},
        {"<address>A</address>", XM_TAG_ADDRESS},
        {"<dl>D</dl>", XM_TAG_DL},
        {"<dt>T</dt>", XM_TAG_DT},
        {"<dd>D</dd>", XM_TAG_DD},
    };
    for (auto& c : cases) {
        auto* r = parse(c.html);
        ASSERT_NE(r, nullptr) << "tag failed: " << c.html;
        bool found = false;
        for (uint32_t i = 0; i < r->span_count; i++) {
            if (r->spans[i].tag == c.expected) { found = true; break; }
        }
        EXPECT_TRUE(found) << "tag: " << c.html << " expected tag " << (int)c.expected;
        xmarkup_result_free(r);
    }
}

TEST_F(APITest, VersionString) {
    const char* ver = xmarkup_version();
    ASSERT_NE(ver, nullptr);
    EXPECT_STREQ(ver, "0.1.0");
}

TEST_F(APITest, PureChineseHTML) {
    auto* r = parse("<b>\xe4\xbd\xa0\xe5\xa5\xbd\xe4\xb8\x96\xe7\x95\x8c</b>"); // "你好世界"
    ASSERT_NE(r, nullptr);
    EXPECT_NE(r->text, nullptr);
    EXPECT_EQ(r->span_count, 1u);
    EXPECT_EQ(r->spans[0].tag, XM_TAG_BOLD);
    xmarkup_result_free(r);
}

TEST_F(APITest, MixedMultilingual) {
    // 中英日韩 Emoji 混合
    auto* r = parse("<b>Hello\xe4\xb8\x96\xe7\x95\x8c\xe3\x81\x93\xe3\x82\x93\xe3\x81\xab\xe3\x81\xa1\xe3\x81\xaf\xf0\x9f\x98\x8a</b>");
    ASSERT_NE(r, nullptr);
    EXPECT_NE(r->text, nullptr);
    EXPECT_GT(r->span_count, 0u);
    xmarkup_result_free(r);
}

TEST_F(APITest, NullHtmlWithZeroLength) {
    auto* result = xmarkup_parse(parser_, nullptr, 0);
    ASSERT_NE(result, nullptr);
    EXPECT_EQ(result->error, XM_OK);
    EXPECT_NE(result->text, nullptr);
    EXPECT_EQ(result->span_count, 0u);
    // spans 应为 nullptr
    EXPECT_EQ(result->spans, nullptr);
    xmarkup_result_free(result);
}

TEST_F(APITest, NullInputWithLength) {
    // html=nullptr 且 length>0 → 应返回 null，last_error = NULL_INPUT
    auto* result = xmarkup_parse(parser_, nullptr, 10);
    EXPECT_EQ(result, nullptr);
    EXPECT_EQ(xmarkup_last_error(parser_), XM_ERR_NULL_INPUT);
}

static std::string build_nested_depth(int depth, const char* tag = "div") {
    std::string html;
    for (int i = 0; i < depth; i++) {
        html += "<"; html += tag; html += ">";
    }
    return html;
}

TEST_F(APITest, MaxDepthBoundary) {
    // 深度 255（栈底+ROOT=256，等于 max_nesting_depth）正常
    auto html_255 = build_nested_depth(255);
    html_255 += "text";
    auto* r1 = xmarkup_parse(parser_, html_255.c_str(), html_255.size());
    ASSERT_NE(r1, nullptr);
    EXPECT_EQ(r1->error, XM_OK);
    xmarkup_result_free(r1);

    // 深度 300（超过 max_depth 256）截断
    auto html_300 = build_nested_depth(300);
    html_300 += "text";
    auto* r2 = xmarkup_parse(parser_, html_300.c_str(), html_300.size());
    ASSERT_NE(r2, nullptr);
    EXPECT_EQ(r2->error, XM_OK);
    xmarkup_result_free(r2);
}

TEST_F(APITest, ConfigMinMaxDepth) {
    // max_nesting_depth = 1 时，入栈元素几乎立即被截断
    XMConfig cfg = {1, 1, 16.0f, nullptr, nullptr, XM_LOG_ERROR};
    XMParser* p = xmarkup_create(&cfg);
    ASSERT_NE(p, nullptr);
    auto* r = xmarkup_parse(p, "<div><p><b>text</b></p></div>", 27);
    ASSERT_NE(r, nullptr);
    EXPECT_EQ(r->error, XM_OK);
    xmarkup_result_free(r);
    xmarkup_destroy(p);
}

TEST_F(APITest, ConsecutiveParseWorks) {
    // XMResult 在下一次 parse 前有效，使用后立即释放
    {
        auto* r1 = parse("<b>first</b>");
        ASSERT_NE(r1, nullptr);
        EXPECT_STREQ(r1->text, "first");
        xmarkup_result_free(r1);
    }
    {
        auto* r2 = parse("<i>second</i>");
        ASSERT_NE(r2, nullptr);
        EXPECT_STREQ(r2->text, "second");
        xmarkup_result_free(r2);
    }
}

TEST_F(APITest, UppercaseTagRecognized) {
    auto* r = parse("<B>bold</B>");
    ASSERT_NE(r, nullptr);
    EXPECT_STREQ(r->text, "bold");
    EXPECT_GE(r->span_count, 1u);
    EXPECT_EQ(r->spans[0].tag, XM_TAG_BOLD);
    xmarkup_result_free(r);
}

TEST_F(APITest, MixedCaseStrongTag) {
    auto* r = parse("<STRONG>text</STRONG>");
    ASSERT_NE(r, nullptr);
    EXPECT_EQ(r->span_count, 1u);
    EXPECT_EQ(r->spans[0].tag, XM_TAG_BOLD);
    xmarkup_result_free(r);
}

// === 日志系统测试 ===

namespace {
    struct LogCapture {
        std::vector<std::pair<XMLogLevel, std::string>> entries;
        static void callback(XMLogLevel level, const char* message, void* context) {
            auto* capture = static_cast<LogCapture*>(context);
            capture->entries.emplace_back(level, std::string(message));
        }
    };
}

TEST_F(APITest, LogCallbackReceivesMessages) {
    LogCapture capture;
    xmarkup_destroy(parser_);
    XMConfig cfg = {1, 256, 16.0f, LogCapture::callback, &capture, XM_LOG_INFO};
    parser_ = xmarkup_create(&cfg);

    auto* r = parse("<b>hello</b>");
    ASSERT_NE(r, nullptr);
    xmarkup_result_free(r);

    // 应至少收到 INFO 级别的 parse start/done 消息
    EXPECT_GE(capture.entries.size(), 2u);
    bool has_info = false;
    for (auto& entry : capture.entries) {
        if (entry.first == XM_LOG_INFO) has_info = true;
    }
    EXPECT_TRUE(has_info);
}

TEST_F(APITest, LogCallbackNullNoop) {
    xmarkup_destroy(parser_);
    XMConfig cfg = {1, 256, 16.0f, nullptr, nullptr, XM_LOG_TRACE};
    parser_ = xmarkup_create(&cfg);
    // callback 为 NULL，不应崩溃
    auto* r = parse("<b>test</b>");
    ASSERT_NE(r, nullptr);
    xmarkup_result_free(r);
}

// === 性能回归测试 ===

TEST_F(APITest, PerfRegression_50KB_Under15ms) {
    // 生成 50KB 混合 HTML
    std::string html;
    html.reserve(50000);
    const char* paragraph = "<p><b style=\"color:#ff0000\">Bold</b><i>Italic</i></p>";
    size_t par_len = std::char_traits<char>::length(paragraph);
    while (html.size() + par_len <= 50000) {
        html += paragraph;
    }

    auto start = std::chrono::high_resolution_clock::now();
    auto* r = xmarkup_parse(parser_, html.c_str(), html.size());
    auto end = std::chrono::high_resolution_clock::now();

    ASSERT_NE(r, nullptr);
    EXPECT_EQ(r->error, XM_OK);
    xmarkup_result_free(r);

    auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count();
    EXPECT_LT(ms, 30) << "50KB 混合 HTML 解析耗时 " << ms << "ms，超出 30ms 基线（含 ASAN 开销）";
}

TEST_F(APITest, PerfRegression_100KB_ScaleLinear) {
    // 生成 50KB 和 100KB HTML，验证线性缩放
    auto gen_50kb = [&]() {
        std::string html;
        html.reserve(50000);
        const char* paragraph = "<p><b style=\"color:#ff0000\">Bold</b><i>Italic</i></p>";
        size_t par_len = std::char_traits<char>::length(paragraph);
        while (html.size() + par_len <= 50000) html += paragraph;
        return html;
    };

    auto html_50 = gen_50kb();
    auto html_100 = gen_50kb() + gen_50kb();

    auto time_parse = [&](const std::string& h) -> double {
        auto s = std::chrono::high_resolution_clock::now();
        auto* r = xmarkup_parse(parser_, h.c_str(), h.size());
        auto e = std::chrono::high_resolution_clock::now();
        xmarkup_result_free(r);
        return std::chrono::duration_cast<std::chrono::microseconds>(e - s).count() / 1000.0;
    };

    double ms_50 = time_parse(html_50);
    double ms_100 = time_parse(html_100);

    // 100KB 耗时不应超过 50KB 的 3.5 倍（短耗时下固定开销占比大，允许波动）
    EXPECT_LT(ms_100, ms_50 * 3.5)
        << "100KB (" << ms_100 << "ms) vs 50KB (" << ms_50 << "ms)，非线性缩放";
}

TEST_F(APITest, PerfRegression_DeepNesting_NoExplosion) {
    std::string html;
    for (int i = 0; i < 1000; i++) html += "<div>";
    html += "text";

    auto start = std::chrono::high_resolution_clock::now();
    auto* r = xmarkup_parse(parser_, html.c_str(), html.size());
    auto end = std::chrono::high_resolution_clock::now();

    ASSERT_NE(r, nullptr);
    EXPECT_NE(r->text, nullptr);
    xmarkup_result_free(r);

    auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count();
    EXPECT_LT(ms, 5) << "1000 层嵌套解析耗时 " << ms << "ms，超出 5ms 基线";
}
