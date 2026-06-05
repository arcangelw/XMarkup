#include <gtest/gtest.h>
#include "tree_builder.h"
#include "tokenizer.h"

using namespace xmarkup;

class TreeBuilderTest : public ::testing::Test {
protected:
    ASTNode parse(const char* html) {
        Tokenizer tok(html);
        std::vector<Token> tokens;
        while (tok.has_next()) tokens.push_back(tok.next());
        TreeBuilder builder;
        return builder.build(tokens);
    }
};

TEST_F(TreeBuilderTest, SimpleNesting) {
    auto root = parse("<b>text</b>");
    ASSERT_EQ(root.children.size(), 1u);
    auto& b_node = root.children[0];
    EXPECT_EQ(b_node.type, ASTNode::ELEMENT);
    EXPECT_EQ(b_node.tag_name, "b");
    ASSERT_EQ(b_node.children.size(), 1u);
    EXPECT_EQ(b_node.children[0].type, ASTNode::TEXT);
    EXPECT_EQ(b_node.children[0].text, "text");
}

TEST_F(TreeBuilderTest, NestedTags) {
    auto root = parse("<b><i>text</i></b>");
    auto& b = root.children[0];
    EXPECT_EQ(b.tag_name, "b");
    auto& i = b.children[0];
    EXPECT_EQ(i.tag_name, "i");
    EXPECT_EQ(i.children[0].text, "text");
}

TEST_F(TreeBuilderTest, SiblingTags) {
    auto root = parse("<b>A</b><i>B</i>");
    ASSERT_EQ(root.children.size(), 2u);
    EXPECT_EQ(root.children[0].tag_name, "b");
    EXPECT_EQ(root.children[1].tag_name, "i");
}

TEST_F(TreeBuilderTest, MisnestedTags) {
    // <a><b></a></b> — 乱序嵌套，自动纠错
    auto root = parse("<a><b></a></b>");
    // 遇到 </a> 时，弹出 b 和 a；后面的 </b> 找不到匹配，忽略
    // 预期：root 有一个子节点 <a>，其中包含 <b>
    ASSERT_GE(root.children.size(), 1u);
    EXPECT_EQ(root.children[0].tag_name, "a");
}

TEST_F(TreeBuilderTest, UnclosedTags) {
    // 末尾自动补齐 </p></div>
    auto root = parse("<div><p>text");
    ASSERT_EQ(root.children.size(), 1u);
    auto& div = root.children[0];
    EXPECT_EQ(div.tag_name, "div");
    ASSERT_EQ(div.children.size(), 1u);
    auto& p = div.children[0];
    EXPECT_EQ(p.tag_name, "p");
    ASSERT_EQ(p.children.size(), 1u);
    EXPECT_EQ(p.children[0].text, "text");
}

TEST_F(TreeBuilderTest, ExtraCloseTag) {
    // </b> 在开头，找不到匹配，忽略
    auto root = parse("</b>text");
    ASSERT_GE(root.children.size(), 1u);
    EXPECT_EQ(root.children[0].type, ASTNode::TEXT);
    EXPECT_EQ(root.children[0].text, "text");
}

TEST_F(TreeBuilderTest, VoidElementNotStacked) {
    auto root = parse("before<br>after");
    ASSERT_EQ(root.children.size(), 3u);
    EXPECT_EQ(root.children[0].type, ASTNode::TEXT);
    EXPECT_EQ(root.children[0].text, "before");
    EXPECT_EQ(root.children[1].type, ASTNode::ELEMENT);
    EXPECT_EQ(root.children[1].tag_name, "br");
    EXPECT_EQ(root.children[2].type, ASTNode::TEXT);
    EXPECT_EQ(root.children[2].text, "after");
}

TEST_F(TreeBuilderTest, SelfClosingTagNotStacked) {
    auto root = parse("before<img src=\"x.png\"/>after");
    ASSERT_EQ(root.children.size(), 3u);
    EXPECT_EQ(root.children[0].type, ASTNode::TEXT);
    EXPECT_EQ(root.children[0].text, "before");
    EXPECT_EQ(root.children[1].type, ASTNode::ELEMENT);
    EXPECT_EQ(root.children[1].tag_name, "img");
    EXPECT_EQ(root.children[2].type, ASTNode::TEXT);
    EXPECT_EQ(root.children[2].text, "after");
}

TEST_F(TreeBuilderTest, MaxNestingDepth) {
    std::string html;
    for (int i = 0; i < 300; i++) html += "<div>";
    html += "text";
    TreeBuilder builder(256, true);
    Tokenizer tok(html.c_str());
    std::vector<Token> tokens;
    while (tok.has_next()) tokens.push_back(tok.next());
    auto root = builder.build(tokens);
    // 不崩溃，文本保留，深度截断在 256 层
    EXPECT_GT(root.children.size(), 0u);
}
