#include <gtest/gtest.h>
#include "tokenizer.h"

using namespace xmarkup;

TEST(Tokenizer, PureText) {
    Tokenizer t("Hello");
    ASSERT_TRUE(t.has_next());
    Token tok = t.next();
    EXPECT_EQ(tok.type, TokenType::TEXT);
    EXPECT_EQ(tok.raw, "Hello");
    EXPECT_FALSE(t.has_next());
}

TEST(Tokenizer, EmptyInput) {
    Tokenizer t("");
    EXPECT_FALSE(t.has_next());
}

TEST(Tokenizer, SingleStartTag) {
    Tokenizer t("<b>");
    ASSERT_TRUE(t.has_next());
    Token tok = t.next();
    EXPECT_EQ(tok.type, TokenType::START_TAG);
    EXPECT_EQ(tok.tag_name, "b");
    EXPECT_EQ(tok.raw, "<b>");
    EXPECT_FALSE(t.has_next());
}

TEST(Tokenizer, StartTagWithAttributes) {
    Tokenizer t(R"(<a href="url" class="link">)");
    ASSERT_TRUE(t.has_next());
    Token tok = t.next();
    EXPECT_EQ(tok.type, TokenType::START_TAG);
    EXPECT_EQ(tok.tag_name, "a");
    EXPECT_EQ(tok.attributes, R"(href="url" class="link")");
}

TEST(Tokenizer, EndTag) {
    Tokenizer t("</b>");
    Token tok = t.next();
    EXPECT_EQ(tok.type, TokenType::END_TAG);
    EXPECT_EQ(tok.tag_name, "b");
}

TEST(Tokenizer, SelfClosingTag) {
    Tokenizer t("<br/>");
    Token tok = t.next();
    EXPECT_EQ(tok.type, TokenType::SELF_CLOSING_TAG);
    EXPECT_EQ(tok.tag_name, "br");
}

TEST(Tokenizer, VoidTagWithoutSlash) {
    Tokenizer t("<br>");
    Token tok = t.next();
    EXPECT_EQ(tok.type, TokenType::START_TAG);
    EXPECT_EQ(tok.tag_name, "br");
}

TEST(Tokenizer, AttributeDoubleQuoted) {
    Tokenizer t(R"(<a href="http://example.com?a=1&b=2">)");
    Token tok = t.next();
    EXPECT_EQ(tok.type, TokenType::START_TAG);
    EXPECT_EQ(tok.tag_name, "a");
}

TEST(Tokenizer, AttributeSingleQuoted) {
    Tokenizer t("<a href='url'>");
    Token tok = t.next();
    EXPECT_EQ(tok.type, TokenType::START_TAG);
    EXPECT_EQ(tok.tag_name, "a");
}

TEST(Tokenizer, AttributeUnquoted) {
    Tokenizer t("<a href=url>");
    Token tok = t.next();
    EXPECT_EQ(tok.type, TokenType::START_TAG);
    EXPECT_EQ(tok.tag_name, "a");
}

TEST(Tokenizer, AngleBracketInText) {
    Tokenizer t("3 < 5");
    auto tok = t.next();
    EXPECT_EQ(tok.type, TokenType::TEXT);
    // "< 5" 中 < 后跟空格不是合法标签名，回退为文本
}

TEST(Tokenizer, UnclosedTagAtEOF) {
    Tokenizer t("text<unclosed");
    Token tok1 = t.next();
    EXPECT_EQ(tok1.type, TokenType::TEXT);
    EXPECT_EQ(tok1.raw, "text");
    ASSERT_TRUE(t.has_next());
    Token tok2 = t.next();
    // 未闭合的标签，当作 START_TAG 处理
    EXPECT_EQ(tok2.type, TokenType::START_TAG);
    EXPECT_EQ(tok2.tag_name, "unclosed");
}

TEST(Tokenizer, CommentStripping) {
    Tokenizer t("before<!-- comment -->after");
    Token tok1 = t.next();
    EXPECT_EQ(tok1.type, TokenType::TEXT);
    EXPECT_EQ(tok1.raw, "before");
    Token tok2 = t.next();
    EXPECT_EQ(tok2.type, TokenType::TEXT);
    EXPECT_EQ(tok2.raw, "after");
    EXPECT_FALSE(t.has_next());
}

TEST(Tokenizer, ScriptTagSkipped) {
    Tokenizer t("before<script>var x = '<a>';</script>after");
    Token tok1 = t.next();
    EXPECT_EQ(tok1.type, TokenType::TEXT);
    EXPECT_EQ(tok1.raw, "before");
    Token tok2 = t.next();
    EXPECT_EQ(tok2.type, TokenType::TEXT);
    EXPECT_EQ(tok2.raw, "after");
    EXPECT_FALSE(t.has_next());
}

TEST(Tokenizer, StyleTagSkipped) {
    Tokenizer t("before<style>body{color:red}</style>after");
    Token tok1 = t.next();
    EXPECT_EQ(tok1.type, TokenType::TEXT);
    EXPECT_EQ(tok1.raw, "before");
    Token tok2 = t.next();
    EXPECT_EQ(tok2.type, TokenType::TEXT);
    EXPECT_EQ(tok2.raw, "after");
    EXPECT_FALSE(t.has_next());
}

TEST(Tokenizer, MixedContent) {
    Tokenizer t("<b>bold</b>plain<i>italic</i>");
    std::vector<Token> tokens;
    while (t.has_next()) tokens.push_back(t.next());
    ASSERT_EQ(tokens.size(), 7u);
    EXPECT_EQ(tokens[0].type, TokenType::START_TAG);
    EXPECT_EQ(tokens[0].tag_name, "b");
    EXPECT_EQ(tokens[1].type, TokenType::TEXT);
    EXPECT_EQ(tokens[1].raw, "bold");
    EXPECT_EQ(tokens[2].type, TokenType::END_TAG);
    EXPECT_EQ(tokens[2].tag_name, "b");
    EXPECT_EQ(tokens[3].type, TokenType::TEXT);
    EXPECT_EQ(tokens[3].raw, "plain");
    EXPECT_EQ(tokens[4].type, TokenType::START_TAG);
    EXPECT_EQ(tokens[4].tag_name, "i");
    EXPECT_EQ(tokens[5].type, TokenType::TEXT);
    EXPECT_EQ(tokens[5].raw, "italic");
    EXPECT_EQ(tokens[6].type, TokenType::END_TAG);
    EXPECT_EQ(tokens[6].tag_name, "i");
}

TEST(Tokenizer, AttributeWithAngleBracket) {
    Tokenizer tok(R"(<span title="a<b">text</span>)");
    std::vector<Token> tokens;
    while (tok.has_next()) tokens.push_back(tok.next());
    // 属性值中的 < 不应开始新标签
    ASSERT_GE(tokens.size(), 2u);
    EXPECT_EQ(tokens[0].type, TokenType::START_TAG);
}

TEST(Tokenizer, AttributeWithAmpersand) {
    Tokenizer tok(R"(<a href="page?a=1&b=2">link</a>)");
    std::vector<Token> tokens;
    while (tok.has_next()) tokens.push_back(tok.next());
    ASSERT_GE(tokens.size(), 2u);
    EXPECT_EQ(tokens[0].type, TokenType::START_TAG);
}

TEST(Tokenizer, UppercaseTag) {
    Tokenizer t("<DIV>content</DIV>");
    std::vector<Token> tokens;
    while (t.has_next()) tokens.push_back(t.next());
    ASSERT_EQ(tokens.size(), 3u);
    EXPECT_EQ(tokens[0].type, TokenType::START_TAG);
    EXPECT_EQ(tokens[0].tag_name, "div");
    EXPECT_EQ(tokens[2].type, TokenType::END_TAG);
    EXPECT_EQ(tokens[2].tag_name, "div");
}

TEST(Tokenizer, MixedCaseTag) {
    Tokenizer t("<StrOnG>bold</StRoNg>");
    std::vector<Token> tokens;
    while (t.has_next()) tokens.push_back(t.next());
    ASSERT_EQ(tokens.size(), 3u);
    EXPECT_EQ(tokens[0].tag_name, "strong");
    EXPECT_EQ(tokens[2].tag_name, "strong");
}

// ============================================================
// Code Review 修复验证测试
// ============================================================

TEST(Tokenizer, ScriptTagWithSimilarPrefix) {
    // 修复 1: </scriptfoo> 不应被误判为 </script> 的闭合标签
    Tokenizer t("before<script>x</scriptfoo>y</script>after");
    Token tok1 = t.next();
    EXPECT_EQ(tok1.type, TokenType::TEXT);
    EXPECT_EQ(tok1.raw, "before");
    Token tok2 = t.next();
    EXPECT_EQ(tok2.type, TokenType::TEXT);
    EXPECT_EQ(tok2.raw, "after");
    EXPECT_FALSE(t.has_next());
}

TEST(Tokenizer, StyleTagWithSimilarPrefix) {
    // 修复 1: </stylefoo> 不应被误判为 </style> 的闭合标签
    Tokenizer t("before<style>x</stylefoo>y</style>after");
    Token tok1 = t.next();
    EXPECT_EQ(tok1.type, TokenType::TEXT);
    EXPECT_EQ(tok1.raw, "before");
    Token tok2 = t.next();
    EXPECT_EQ(tok2.type, TokenType::TEXT);
    EXPECT_EQ(tok2.raw, "after");
    EXPECT_FALSE(t.has_next());
}

TEST(Tokenizer, TextareaContentNotParsed) {
    // 修复 6: <textarea> 内容不应被作为 HTML 解析
    Tokenizer t("<textarea><b>bold</b></textarea>");
    std::vector<Token> tokens;
    while (t.has_next()) tokens.push_back(t.next());
    // textarea 内容被跳过，不产出任何 START_TAG/END_TAG token
    for (auto& tok : tokens) {
        EXPECT_NE(tok.type, TokenType::START_TAG) << "不应产出内部 <b> 标签";
        EXPECT_NE(tok.type, TokenType::END_TAG) << "不应产出内部 </b> 标签";
    }
}

TEST(Tokenizer, TitleContentNotParsed) {
    // 修复 6: <title> 内容不应被作为 HTML 解析
    Tokenizer t("before<title><b>bold</b></title>after");
    Token tok1 = t.next();
    EXPECT_EQ(tok1.type, TokenType::TEXT);
    EXPECT_EQ(tok1.raw, "before");
    Token tok2 = t.next();
    EXPECT_EQ(tok2.type, TokenType::TEXT);
    EXPECT_EQ(tok2.raw, "after");
    EXPECT_FALSE(t.has_next());
}

TEST(Tokenizer, BooleanAttributes) {
    Tokenizer t(R"(<video autoplay controls src="video.mp4">)");
    ASSERT_TRUE(t.has_next());
    Token tok = t.next();
    EXPECT_EQ(tok.type, TokenType::START_TAG);
    EXPECT_EQ(tok.tag_name, "video");
    // 布尔属性后仍能正确解析 src 属性
    EXPECT_NE(tok.attributes.find("src"), std::string_view::npos);
    EXPECT_NE(tok.attributes.find("autoplay"), std::string_view::npos);
    EXPECT_NE(tok.attributes.find("controls"), std::string_view::npos);
}

TEST(Tokenizer, EmptyAttributeValue) {
    Tokenizer t(R"(<div class="">text</div>)");
    ASSERT_TRUE(t.has_next());
    Token tok = t.next();
    EXPECT_EQ(tok.type, TokenType::START_TAG);
    EXPECT_EQ(tok.tag_name, "div");
    EXPECT_NE(tok.attributes.find(R"(class="")"), std::string_view::npos);
}

TEST(Tokenizer, TabNewlineBetweenAttributes) {
    Tokenizer t("<div\tclass=\"a\"\nid=\"b\">");
    ASSERT_TRUE(t.has_next());
    Token tok = t.next();
    EXPECT_EQ(tok.type, TokenType::START_TAG);
    EXPECT_EQ(tok.tag_name, "div");
}

TEST(Tokenizer, RepeatedHasNext) {
    // 多次调用 has_next() 不改变状态
    Tokenizer t("text");
    EXPECT_TRUE(t.has_next());
    EXPECT_TRUE(t.has_next()); // 重复调用
    Token tok = t.next();
    EXPECT_EQ(tok.type, TokenType::TEXT);
    EXPECT_FALSE(t.has_next());
    EXPECT_FALSE(t.has_next()); // 重复调用
}

TEST(Tokenizer, ConsecutiveAngleBrackets) {
    // <<div> 第一个 < 回退为文本，第二个 < 开始标签
    Tokenizer t("<<div>text");
    Token tok1 = t.next();
    EXPECT_EQ(tok1.type, TokenType::TEXT);
    EXPECT_EQ(tok1.raw, "<");
    Token tok2 = t.next();
    EXPECT_EQ(tok2.type, TokenType::START_TAG);
    EXPECT_EQ(tok2.tag_name, "div");
}

TEST(Tokenizer, SlashNotAtEnd) {
    // <div/attr> 中 '/' 不是自闭合标记，是属性的一部分
    Tokenizer t("<div/attr>");
    ASSERT_TRUE(t.has_next());
    Token tok = t.next();
    EXPECT_EQ(tok.type, TokenType::START_TAG);
    EXPECT_EQ(tok.tag_name, "div");
    // '/' 应出现在属性中
    EXPECT_NE(tok.attributes.find("/attr"), std::string_view::npos);
}

TEST(Tokenizer, UnknownDeclaration) {
    Tokenizer t("text<!foo>after");
    std::vector<Token> tokens;
    while (t.has_next()) tokens.push_back(t.next());
    // <!foo> 被整体跳过（非注释声明）
    ASSERT_EQ(tokens.size(), 2u);
    EXPECT_EQ(tokens[0].type, TokenType::TEXT);
    EXPECT_EQ(tokens[0].raw, "text");
    EXPECT_EQ(tokens[1].type, TokenType::TEXT);
    EXPECT_EQ(tokens[1].raw, "after");
}
