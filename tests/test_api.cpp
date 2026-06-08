#include <gtest/gtest.h>
#include <cstring>
#include <chrono>
#include <thread>
#include <atomic>
#include <vector>
#include <string>
#include "xmarkup/xmarkup.h"

class APITest : public ::testing::Test {
protected:
    void SetUp() override {
        XMConfig cfg = {1, 256, 16.0f};
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

TEST_F(APITest, PreWhitespacePreserved) {
    auto* r = parse("<pre>  spaces  \n  lines  </pre>");
    ASSERT_NE(r, nullptr);
    EXPECT_STREQ(r->text, "  spaces  \n  lines  ");
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
            XMConfig cfg = {1, 256, 16.0f};
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
