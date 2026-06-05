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
