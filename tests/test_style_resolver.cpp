#include <gtest/gtest.h>
#include "style_resolver.h"
#include "tokenizer.h"
#include "tree_builder.h"

using namespace xmarkup;

class StyleResolverTest : public ::testing::Test {
protected:
    FlattenResult resolve(const char* html, float base_font_size = 16.0f) {
        Tokenizer tok(html);
        std::vector<Token> tokens;
        while (tok.has_next()) tokens.push_back(tok.next());
        TreeBuilder tb;
        auto ast = tb.build(tokens);
        StyleResolver sr(base_font_size);
        return sr.resolve(ast);
    }
};

TEST_F(StyleResolverTest, BoldTag) {
    auto r = resolve("<b>bold</b>");
    EXPECT_EQ(r.text, "bold");
    ASSERT_EQ(r.spans.size(), 1u);
    EXPECT_EQ(r.spans[0].tag, XM_TAG_BOLD);
    EXPECT_EQ(r.spans[0].byte_start, 0u);
    EXPECT_EQ(r.spans[0].byte_end, 4u);
}

TEST_F(StyleResolverTest, StrongMapsToBold) {
    auto r = resolve("<strong>bold</strong>");
    EXPECT_EQ(r.text, "bold");
    ASSERT_EQ(r.spans.size(), 1u);
    EXPECT_EQ(r.spans[0].tag, XM_TAG_BOLD);
}

TEST_F(StyleResolverTest, ItalicTag) {
    auto r = resolve("<i>italic</i>");
    ASSERT_EQ(r.spans.size(), 1u);
    EXPECT_EQ(r.spans[0].tag, XM_TAG_ITALIC);
}

TEST_F(StyleResolverTest, EmMapsToItalic) {
    auto r = resolve("<em>italic</em>");
    ASSERT_EQ(r.spans.size(), 1u);
    EXPECT_EQ(r.spans[0].tag, XM_TAG_ITALIC);
}

TEST_F(StyleResolverTest, NestedStyleStacking) {
    auto r = resolve("<b><i>text</i></b>");
    EXPECT_EQ(r.text, "text");
    ASSERT_EQ(r.spans.size(), 2u);
    EXPECT_EQ(r.spans[0].tag, XM_TAG_BOLD);
    EXPECT_EQ(r.spans[1].tag, XM_TAG_ITALIC);
}

TEST_F(StyleResolverTest, LinkTagWithHref) {
    auto r = resolve("<a href=\"http://example.com\">link</a>");
    EXPECT_EQ(r.text, "link");
    ASSERT_EQ(r.spans.size(), 1u);
    EXPECT_EQ(r.spans[0].tag, XM_TAG_LINK);
    EXPECT_EQ(r.spans[0].value, "http://example.com");
}

TEST_F(StyleResolverTest, ImageTagWithSrc) {
    auto r = resolve("<img src=\"photo.jpg\">");
    EXPECT_NE(r.text.find("\xEF\xBF\xBC"), std::string::npos); // 包含 U+FFFC 占位字符
    ASSERT_EQ(r.spans.size(), 1u);
    EXPECT_EQ(r.spans[0].tag, XM_TAG_IMAGE);
    EXPECT_EQ(r.spans[0].value, "photo.jpg");
    EXPECT_GT(r.spans[0].byte_end, r.spans[0].byte_start); // range 非零
}

TEST_F(StyleResolverTest, HeadingTags) {
    auto r = resolve("<h1>Title</h1>");
    ASSERT_EQ(r.spans.size(), 1u);
    EXPECT_EQ(r.spans[0].tag, XM_TAG_HEADING_1);
}

TEST_F(StyleResolverTest, ParagraphTag) {
    auto r = resolve("<p>Hello</p>");
    ASSERT_EQ(r.spans.size(), 1u);
    EXPECT_EQ(r.spans[0].tag, XM_TAG_PARAGRAPH);
}

TEST_F(StyleResolverTest, BlockquoteTag) {
    auto r = resolve("<blockquote>Quote</blockquote>");
    ASSERT_EQ(r.spans.size(), 1u);
    EXPECT_EQ(r.spans[0].tag, XM_TAG_BLOCKQUOTE);
}

TEST_F(StyleResolverTest, PreTag) {
    auto r = resolve("<pre>  code  \n  line  </pre>");
    ASSERT_EQ(r.spans.size(), 1u);
    EXPECT_EQ(r.spans[0].tag, XM_TAG_PREFORMATTED);
    // pre 内空白保留
    EXPECT_EQ(r.text, "  code  \n  line  ");
}

TEST_F(StyleResolverTest, CSSColorName) {
    auto r = resolve(R"(<span style="color:red">text</span>)");
    bool found = false;
    for (auto& s : r.spans) {
        if (s.style == XM_STYLE_FOREGROUND_COLOR && s.value == "#FF0000") found = true;
    }
    EXPECT_TRUE(found);
}

TEST_F(StyleResolverTest, CSSColorHex) {
    auto r = resolve(R"(<span style="color:#ff0000">text</span>)");
    bool found = false;
    for (auto& s : r.spans) {
        if (s.style == XM_STYLE_FOREGROUND_COLOR && s.value == "#FF0000") found = true;
    }
    EXPECT_TRUE(found);
}

TEST_F(StyleResolverTest, CSSFontSizePx) {
    auto r = resolve(R"(<span style="font-size:16px">text</span>)");
    bool found = false;
    for (auto& s : r.spans) {
        if (s.style == XM_STYLE_FONT_SIZE && s.value == "16") found = true;
    }
    EXPECT_TRUE(found);
}

TEST_F(StyleResolverTest, CSSFontSizeEm) {
    auto r = resolve(R"(<span style="font-size:1.5em">text</span>)", 16);
    bool found = false;
    for (auto& s : r.spans) {
        if (s.style == XM_STYLE_FONT_SIZE && s.value == "24") found = true;
    }
    EXPECT_TRUE(found);
}

TEST_F(StyleResolverTest, SourceInVideoContext) {
    auto r = resolve("<video><source src=\"a.mp4\" type=\"video/mp4\"></video>");
    bool found_video_source = false;
    for (auto& s : r.spans) {
        if (s.tag == XM_TAG_VIDEO_SOURCE) {
            found_video_source = true;
            EXPECT_EQ(s.value, "a.mp4");
        }
    }
    EXPECT_TRUE(found_video_source);
}

TEST_F(StyleResolverTest, SourceInAudioContext) {
    auto r = resolve("<audio><source src=\"a.mp3\" type=\"audio/mpeg\"></audio>");
    bool found_audio_source = false;
    for (auto& s : r.spans) {
        if (s.tag == XM_TAG_AUDIO_SOURCE) {
            found_audio_source = true;
            EXPECT_EQ(s.value, "a.mp3");
        }
    }
    EXPECT_TRUE(found_audio_source);
}

TEST_F(StyleResolverTest, ListTags) {
    auto r = resolve("<ul><li>item1</li><li>item2</li></ul>");
    EXPECT_TRUE(r.text.find("item1") != std::string::npos);
    bool found_ul = false, found_li = false;
    for (auto& s : r.spans) {
        if (s.tag == XM_TAG_LIST_UNORDERED) found_ul = true;
        if (s.tag == XM_TAG_LIST_ITEM) found_li = true;
    }
    EXPECT_TRUE(found_ul);
    EXPECT_TRUE(found_li);
}

TEST_F(StyleResolverTest, TableTags) {
    auto r = resolve("<table><tr><td>cell</td></tr></table>");
    EXPECT_TRUE(r.text.find("cell") != std::string::npos);
    bool found_table = false, found_tr = false, found_td = false;
    for (auto& s : r.spans) {
        if (s.tag == XM_TAG_TABLE) found_table = true;
        if (s.tag == XM_TAG_TABLE_ROW) found_tr = true;
        if (s.tag == XM_TAG_TABLE_CELL) found_td = true;
    }
    EXPECT_TRUE(found_table);
    EXPECT_TRUE(found_tr);
    EXPECT_TRUE(found_td);
}

TEST_F(StyleResolverTest, CSSFontSizeFloatBase) {
    // 验证浮点 base_font_size 精度：1.5em × 14.5 = 21.75
    auto r = resolve(R"(<span style="font-size:1.5em">text</span>)", 14.5f);
    bool found = false;
    for (auto& s : r.spans) {
        if (s.style == XM_STYLE_FONT_SIZE && s.value == "21.75") found = true;
    }
    EXPECT_TRUE(found);
}

TEST_F(StyleResolverTest, CSSFontSizeFloatPt) {
    // 验证 pt→px 浮点换算：12pt × 1.333 ≈ 15.996 → "16"（保留有效小数）
    auto r = resolve(R"(<span style="font-size:12pt">text</span>)");
    bool found = false;
    for (auto& s : r.spans) {
        if (s.style == XM_STYLE_FONT_SIZE) {
            // 接受合理的浮点输出
            found = (s.value == "16" || s.value == "15.996" || s.value == "16.00");
        }
    }
    EXPECT_TRUE(found);
}

TEST_F(StyleResolverTest, ImageInsertsPlaceholder) {
    auto r = resolve("Hello <img src=\"photo.jpg\"> World");
    // image 应插入 U+FFFC 占位字符，span range 非零
    bool found = false;
    for (auto& s : r.spans) {
        if (s.tag == XM_TAG_IMAGE) {
            found = true;
            EXPECT_GT(s.byte_end, s.byte_start); // range 非零长度
        }
    }
    EXPECT_TRUE(found);
    // text 中应包含 U+FFFC (UTF-8: EF BF BC)
    EXPECT_NE(r.text.find("\xEF\xBF\xBC"), std::string::npos);
}

TEST_F(StyleResolverTest, LineBreakInsertsNewline) {
    auto r = resolve("before<br>after");
    bool found_br = false;
    for (auto& s : r.spans) {
        if (s.tag == XM_TAG_LINE_BREAK) {
            found_br = true;
            EXPECT_GT(s.byte_end, s.byte_start); // range 非零
        }
    }
    EXPECT_TRUE(found_br);
    EXPECT_NE(r.text.find('\n'), std::string::npos);
}

TEST_F(StyleResolverTest, HorizontalRuleInsertsPlaceholder) {
    auto r = resolve("before<hr>after");
    bool found = false;
    for (auto& s : r.spans) {
        if (s.tag == XM_TAG_HORIZONTAL_RULE) {
            found = true;
            EXPECT_GT(s.byte_end, s.byte_start);
        }
    }
    EXPECT_TRUE(found);
}

TEST_F(StyleResolverTest, VideoInsertsPlaceholder) {
    auto r = resolve("<video><source src=\"a.mp4\"></video>");
    bool found = false;
    for (auto& s : r.spans) {
        if (s.tag == XM_TAG_VIDEO) {
            found = true;
            EXPECT_GT(s.byte_end, s.byte_start);
        }
    }
    EXPECT_TRUE(found);
}

TEST_F(StyleResolverTest, AudioInsertsPlaceholder) {
    auto r = resolve("<audio><source src=\"a.mp3\"></audio>");
    bool found = false;
    for (auto& s : r.spans) {
        if (s.tag == XM_TAG_AUDIO) {
            found = true;
            EXPECT_GT(s.byte_end, s.byte_start);
        }
    }
    EXPECT_TRUE(found);
}

TEST_F(StyleResolverTest, ParagraphSeparation) {
    auto r = resolve("<p>First</p><p>Second</p>");
    EXPECT_NE(r.text.find("First"), std::string::npos);
    EXPECT_NE(r.text.find("Second"), std::string::npos);
    EXPECT_NE(r.text.find('\n'), std::string::npos);
}

TEST_F(StyleResolverTest, CSSNegativeFontSize) {
    auto r = resolve(R"(<span style="font-size:-10px">text</span>)");
    EXPECT_NE(r.text, "");
}

TEST_F(StyleResolverTest, CSSZeroFontSize) {
    auto r = resolve(R"(<span style="font-size:0px">text</span>)");
    bool found = false;
    for (auto& s : r.spans) {
        if (s.style == XM_STYLE_FONT_SIZE && s.value == "0") found = true;
    }
    EXPECT_TRUE(found);
}

TEST_F(StyleResolverTest, EmptyStyleAttribute) {
    auto r = resolve(R"(<span style="">text</span>)");
    EXPECT_EQ(r.text, "text");
}

TEST_F(StyleResolverTest, CSSInvalidColorValue) {
    auto r = resolve(R"(<span style="color:notacolor">text</span>)");
    EXPECT_EQ(r.text, "text");
}

TEST_F(StyleResolverTest, VideoTagWithDirectSrc) {
    auto r = resolve("<video src=\"movie.mp4\"></video>");
    bool found = false;
    for (auto& s : r.spans) {
        if (s.tag == XM_TAG_VIDEO) {
            found = true;
            EXPECT_EQ(s.value, "movie.mp4");
            EXPECT_GT(s.byte_end, s.byte_start);
        }
    }
    EXPECT_TRUE(found);
    EXPECT_NE(r.text.find("\xEF\xBF\xBC"), std::string::npos);
}

TEST_F(StyleResolverTest, AudioTagWithDirectSrc) {
    auto r = resolve("<audio src=\"song.mp3\"></audio>");
    bool found = false;
    for (auto& s : r.spans) {
        if (s.tag == XM_TAG_AUDIO) {
            found = true;
            EXPECT_EQ(s.value, "song.mp3");
            EXPECT_GT(s.byte_end, s.byte_start);
        }
    }
    EXPECT_TRUE(found);
    EXPECT_NE(r.text.find("\xEF\xBF\xBC"), std::string::npos);
}

TEST_F(StyleResolverTest, VideoTagWithSourceChildSrcFallback) {
    auto r = resolve("<video><source src=\"a.mp4\" type=\"video/mp4\"></video>");
    bool found_video = false, found_source = false;
    for (auto& s : r.spans) {
        if (s.tag == XM_TAG_VIDEO) {
            found_video = true;
            EXPECT_TRUE(s.value.empty());
        }
        if (s.tag == XM_TAG_VIDEO_SOURCE) {
            found_source = true;
            EXPECT_EQ(s.value, "a.mp4");
        }
    }
    EXPECT_TRUE(found_video);
    EXPECT_TRUE(found_source);
}
