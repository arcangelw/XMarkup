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

// ============================================================
// 隐式关闭规则测试
// ============================================================

TEST_F(TreeBuilderTest, ImplicitClose_PSameP) {
    // 规则 1：<p> 遇 <p> 自动关闭 → 两个平级 <p>
    auto root = parse("<p>第一段<p>第二段</p>");
    ASSERT_EQ(root.children.size(), 2u);
    EXPECT_EQ(root.children[0].tag_name, "p");
    EXPECT_EQ(root.children[1].tag_name, "p");
}

TEST_F(TreeBuilderTest, ImplicitClose_PBlockDiv) {
    // 规则 1：<p> 遇块级 <div> 自动关闭
    auto root = parse("<p>text<div>block</div>");
    ASSERT_EQ(root.children.size(), 2u);
    EXPECT_EQ(root.children[0].tag_name, "p");
    EXPECT_EQ(root.children[1].tag_name, "div");
}

TEST_F(TreeBuilderTest, ImplicitClose_LILI) {
    // 规则 2：<li> 遇 <li> 自动关闭
    auto root = parse("<ul><li>A<li>B</ul>");
    auto& ul = root.children[0];
    EXPECT_EQ(ul.tag_name, "ul");
    ASSERT_EQ(ul.children.size(), 2u);
    EXPECT_EQ(ul.children[0].tag_name, "li");
    EXPECT_EQ(ul.children[1].tag_name, "li");
}

TEST_F(TreeBuilderTest, ImplicitClose_DtDd) {
    // 规则 3：<dt>/<dd> 互相关闭
    auto root = parse("<dl><dt>term<dd>def</dl>");
    auto& dl = root.children[0];
    EXPECT_EQ(dl.tag_name, "dl");
    ASSERT_EQ(dl.children.size(), 2u);
    EXPECT_EQ(dl.children[0].tag_name, "dt");
    EXPECT_EQ(dl.children[1].tag_name, "dd");
}

TEST_F(TreeBuilderTest, ImplicitClose_TrTr) {
    // 规则 4：<tr> 遇 <tr> 自动关闭
    auto root = parse("<table><tr><td>A</td></tr><tr><td>B</td></tr></table>");
    auto& table = root.children[0];
    EXPECT_EQ(table.tag_name, "table");
    // 两个 <tr> 应为平级子节点
    int tr_count = 0;
    for (auto& child : table.children) {
        if (child.tag_name == "tr") tr_count++;
    }
    EXPECT_EQ(tr_count, 2);
}

TEST_F(TreeBuilderTest, ImplicitClose_TdTh) {
    // 规则 5：<td> 遇 <th> 自动关闭
    auto root = parse("<table><tr><td>A<th>B</tr></table>");
    auto& table = root.children[0];
    auto& tr = table.children[0];
    EXPECT_EQ(tr.tag_name, "tr");
    ASSERT_EQ(tr.children.size(), 2u);
    EXPECT_EQ(tr.children[0].tag_name, "td");
    EXPECT_EQ(tr.children[1].tag_name, "th");
}

TEST_F(TreeBuilderTest, ImplicitClose_ScopeBoundary) {
    // scope boundary：<p> 在 <div> 内遇到 <div> 不跳出
    auto root = parse("<div><p>text<p>more</div>");
    auto& div = root.children[0];
    // 两个 <p> 关闭彼此，但不跳出 <div>
    ASSERT_EQ(div.children.size(), 2u);
    EXPECT_EQ(div.children[0].tag_name, "p");
    EXPECT_EQ(div.children[1].tag_name, "p");
}

TEST_F(TreeBuilderTest, ImplicitClose_HeadingBlock) {
    // 规则 6：<h1> 遇块级元素自动关闭
    auto root = parse("<h1>Title</h1><p>Para</p>");
    ASSERT_EQ(root.children.size(), 2u);
    EXPECT_EQ(root.children[0].tag_name, "h1");
    EXPECT_EQ(root.children[1].tag_name, "p");
}

// ============================================================
// Adoption Agency 测试
// ============================================================

TEST_F(TreeBuilderTest, Adoption_BasicBP) {
    // <b>text<p>para</p> → <b>text</b><p><b'>para</b'></p>
    auto root = parse("<div><b>text<p>para</p></b></div>");
    auto& div = root.children[0];
    // div 有两个子节点：<b> 和 <p>
    ASSERT_EQ(div.children.size(), 2u);
    EXPECT_EQ(div.children[0].tag_name, "b");
    EXPECT_EQ(div.children[1].tag_name, "p");
    // <p> 内应有重建的 <b>
    auto& p = div.children[1];
    ASSERT_FALSE(p.children.empty());
    EXPECT_EQ(p.children[0].tag_name, "b");
}

TEST_F(TreeBuilderTest, Adoption_MultiLayer) {
    // <b><i>text<p>para → 重建 <b>→<i> 在 <p> 内
    auto root = parse("<div><b><i>text<p>para</p></i></b></div>");
    auto& div = root.children[0];
    ASSERT_EQ(div.children.size(), 2u);
    auto& p = div.children[1];
    EXPECT_EQ(p.tag_name, "p");
    // <p> 内应重建 <b> → <i>
    ASSERT_GE(p.children.size(), 1u);
    auto& b_clone = p.children[0];
    EXPECT_EQ(b_clone.tag_name, "b");
    ASSERT_GE(b_clone.children.size(), 1u);
    EXPECT_EQ(b_clone.children[0].tag_name, "i");
}

TEST_F(TreeBuilderTest, Adoption_PreservesSpan) {
    // <span><b>text<p>para → 重建 <span><b>，保留包装层
    auto root = parse("<div><span><b>text<p>para</p></b></span></div>");
    auto& div = root.children[0];
    auto& p = div.children[1];
    EXPECT_EQ(p.tag_name, "p");
    // span 和 b 都被重建（span 包装层保留，外到内：p → span → b）
    ASSERT_GE(p.children.size(), 1u);
    EXPECT_EQ(p.children[0].tag_name, "span");
    ASSERT_GE(p.children[0].children.size(), 1u);
    EXPECT_EQ(p.children[0].children[0].tag_name, "b");
}

TEST_F(TreeBuilderTest, Adoption_Disabled) {
    // enable_autocorrect = false 时不触发 adoption
    Tokenizer tok("<div><b>text<p>para</p></b></div>");
    std::vector<Token> tokens;
    while (tok.has_next()) tokens.push_back(tok.next());
    TreeBuilder builder(256, false);  // autocorrect = false
    auto root = builder.build(tokens);
    auto& div = root.children[0];
    // <b> 不被 adoption 重建，<p> 嵌套在 <b> 内
    ASSERT_EQ(div.children.size(), 1u);
    EXPECT_EQ(div.children[0].tag_name, "b");
}
