# XMarkup C++ 核心解析引擎实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 实现一个 C++17 高性能 HTML 富文本解析引擎，输出纯文本 + UTF-16 索引样式区间，供三端桥接层消费。

**架构：** 管线式处理——Tokenizer（状态机词法分析）→ TreeBuilder（栈式 AST + 自动纠错）→ StyleResolver + EntityDecoder（标签映射 + CSS 解析 + 实体解码）→ UTF16Indexer（编码映射）→ XMResult。对外暴露 C 风格 `extern "C"` API。

**技术栈：** C++17、CMake 3.16+、GoogleTest v1.14.0、`std::string_view` 零拷贝。

**设计规格：** `docs/superpowers/specs/2026-06-05-xmarkup-core-design.md`

---

## 文件职责清单

| 文件 | 职责 |
|------|------|
| `CMakeLists.txt` | 顶层构建配置，C++17 标准 |
| `core/include/xmarkup/xmarkup.h` | 唯一公共 C API 头文件，定义所有跨语言数据契约 |
| `core/CMakeLists.txt` | 核心库构建配置，编译为 `xmarkup_core` 静态库 |
| `core/src/tokenizer.h` | Tokenizer 内部头文件，定义 State 枚举、Token 结构、Tokenizer 类 |
| `core/src/tokenizer.cpp` | 状态机词法分析器实现 |
| `core/src/tree_builder.h` | TreeBuilder 内部头文件，定义 ASTNode、TreeBuilder 类 |
| `core/src/tree_builder.cpp` | 栈式 AST 构建器 + 自动纠错 + `<pre>` 追踪 |
| `core/src/style_resolver.h` | StyleResolver 内部头文件，定义标签映射表、CSS 解析接口 |
| `core/src/style_resolver.cpp` | 标签语义映射 + CSS 行内样式解析 + 父标签栈 |
| `core/src/entity_decoder.h` | EntityDecoder 内部头文件 |
| `core/src/entity_decoder.cpp` | HTML 实体解码（命名/数字/十六进制） |
| `core/src/utf16_indexer.h` | UTF16Indexer 内部头文件 |
| `core/src/utf16_indexer.cpp` | UTF-8 byte offset → UTF-16 码元索引映射 |
| `core/src/parser.h` | Parser 内部头文件，组合所有模块 |
| `core/src/parser.cpp` | 内部 Parser 类，编排完整管线 |
| `core/src/api.cpp` | `extern "C"` API 薄封装，C++ Parser → C 接口 |
| `tests/CMakeLists.txt` | 测试构建配置，GoogleTest 集成 |
| `tests/test_tokenizer.cpp` | 词法分析器单元测试 |
| `tests/test_tree_builder.cpp` | AST 构建器单元测试 |
| `tests/test_style_resolver.cpp` | 样式解析器单元测试 |
| `tests/test_entity_decoder.cpp` | 实体解码器单元测试 |
| `tests/test_utf16_indexer.cpp` | UTF-16 索引器单元测试 |
| `tests/test_api.cpp` | C API 集成测试 + 性能测试 + 线程安全测试 |
| `tests/test_data/simple.html` | 简单 HTML 测试文件 |
| `tests/test_data/nested_mismatch.html` | 乱序嵌套测试文件 |
| `tests/test_data/stress_50kb.html` | 50KB 压力测试文件 |
| `tests/test_data/malicious.html` | 恶意构造 HTML 文件 |

---

## 任务 1：项目脚手架搭建

**文件：**
- 创建：`CMakeLists.txt`
- 创建：`core/CMakeLists.txt`
- 创建：`core/include/xmarkup/xmarkup.h`
- 创建：`tests/CMakeLists.txt`

- [ ] **步骤 1：创建顶层 CMakeLists.txt**

```cmake
cmake_minimum_required(VERSION 3.16)
project(XMarkup VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(MSVC)
    add_compile_options(/W4 /WX)
else()
    add_compile_options(-Wall -Wextra -Wpedantic -Werror)
endif()

add_subdirectory(core)
add_subdirectory(tests)
```

- [ ] **步骤 2：创建 core/include/xmarkup/xmarkup.h 公共头文件**

写入规格文档第 3.1 节的完整头文件内容（包含 XMTagType、XMStyleType、XMRange、XMSpan、XMResult、XMConfig、XMError、XMParser、所有函数声明）。

- [ ] **步骤 3：创建 core/CMakeLists.txt**

```cmake
add_library(xmarkup_core STATIC
    src/tokenizer.cpp
    src/tree_builder.cpp
    src/style_resolver.cpp
    src/entity_decoder.cpp
    src/utf16_indexer.cpp
    src/parser.cpp
    src/api.cpp
)

target_include_directories(xmarkup_core
    PUBLIC  include
    PRIVATE src
)

set_target_properties(xmarkup_core PROPERTIES
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN ON
)
```

- [ ] **步骤 4：创建 tests/CMakeLists.txt**

```cmake
include(FetchContent)
FetchContent_Declare(
    googletest
    GIT_REPOSITORY https://github.com/google/googletest.git
    GIT_TAG        v1.14.0
)
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(googletest)

enable_testing()

foreach(test_name
    test_tokenizer
    test_tree_builder
    test_style_resolver
    test_entity_decoder
    test_utf16_indexer
    test_api
)
    add_executable(${test_name} ${test_name}.cpp)
    target_link_libraries(${test_name}
        PRIVATE xmarkup_core GTest::gtest_main
    )
    add_test(NAME ${test_name} COMMAND ${test_name})
endforeach()
```

- [ ] **步骤 5：创建所有空源文件（占位，确保 CMake 能找到）**

创建以下文件，每个只包含最小内容：

```cpp
// core/src/tokenizer.cpp
#include "tokenizer.h"
```

对 `tree_builder.cpp`、`style_resolver.cpp`、`entity_decoder.cpp`、`utf16_indexer.cpp`、`parser.cpp`、`api.cpp` 做同样处理，每个 include 对应的 `.h` 头文件。

创建以下内部头文件，每个包含 `#pragma once` 和最小骨架：

- `core/src/tokenizer.h`
- `core/src/tree_builder.h`
- `core/src/style_resolver.h`
- `core/src/entity_decoder.h`
- `core/src/utf16_indexer.h`
- `core/src/parser.h`

创建所有测试文件，每个包含：
```cpp
#include <gtest/gtest.h>
// 测试将在后续任务中填充
```

创建 `tests/test_data/` 目录及 4 个空 `.html` 占位文件。

- [ ] **步骤 6：运行 CMake 配置确认能构建**

```bash
cmake -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build
```

预期：构建成功（可能有未定义符号的链接警告，因为源文件为空，但不应有编译错误）。

- [ ] **步骤 7：Commit**

```bash
git add CMakeLists.txt core/ tests/
git commit -m "chore: 项目脚手架搭建（CMake + GoogleTest + 目录结构）"
```

---

## 任务 2：Tokenizer 词法分析器

**文件：**
- 创建：`core/src/tokenizer.h`
- 创建：`core/src/tokenizer.cpp`
- 创建：`tests/test_tokenizer.cpp`

- [ ] **步骤 1：编写 tokenizer.h 内部头文件**

```cpp
#pragma once

#include <cstdint>
#include <string_view>
#include <vector>

namespace xmarkup {

enum class TokenType {
    TEXT,
    START_TAG,
    END_TAG,
    SELF_CLOSING_TAG,
};

enum class TokenizerState {
    DATA,
    TAG_OPEN,
    TAG_NAME,
    END_TAG_OPEN,
    BEFORE_ATTR_NAME,
    ATTR_NAME,
    AFTER_ATTR_NAME,
    ATTR_VALUE_DOUBLE_Q,
    ATTR_VALUE_SINGLE_Q,
    ATTR_VALUE_UNQUOTED,
    SELF_CLOSING,
    COMMENT,
    COMMENT_DASH1,
    COMMENT_DASH2,
    RAWTEXT,
};

struct Token {
    TokenType        type;
    std::string_view raw;
    std::string_view tag_name;
    std::string_view attributes;
};

class Tokenizer {
public:
    explicit Tokenizer(std::string_view html);

    bool has_next() const;
    Token next();

private:
    char advance();
    char peek() const;
    bool is_eof() const;
    bool is_alpha(char c) const;
    bool is_whitespace(char c) const;
    void skip_rawtext(const char* end_tag);

    std::string_view html_;
    size_t pos_ = 0;
    TokenizerState state_ = TokenizerState::DATA;
    bool has_token_ = false;
    Token pending_token_;
};

} // namespace xmarkup
```

- [ ] **步骤 2：编写第一个失败测试——纯文本**

在 `tests/test_tokenizer.cpp` 中：

```cpp
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
```

- [ ] **步骤 3：运行测试确认失败**

```bash
cmake --build build && ./build/tests/test_tokenizer --gtest_filter=Tokenizer.PureText
```

预期：编译失败或链接错误（函数未实现）。

- [ ] **步骤 4：实现 Tokenizer 的 DATA 状态和 TEXT Token 输出**

在 `core/src/tokenizer.cpp` 中实现 `Tokenizer` 类的构造函数、`has_next()`、`next()` 方法。先只实现 `DATA` 状态：在 `<` 之前的字符收集为 TEXT Token。

- [ ] **步骤 5：运行测试确认通过**

```bash
./build/tests/test_tokenizer --gtest_filter=Tokenizer.PureText
./build/tests/test_tokenizer --gtest_filter=Tokenizer.EmptyInput
```

预期：两个测试 PASS。

- [ ] **步骤 6：编写开始标签测试**

```cpp
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
    EXPECT_EQ(tok.attributes, R"( href="url" class="link")");
}
```

- [ ] **步骤 7：实现 TAG_OPEN → TAG_NAME → BEFORE_ATTR_NAME → DATA 状态转换**

- [ ] **步骤 8：运行测试确认通过**

- [ ] **步骤 9：编写闭合标签、自闭合标签测试**

```cpp
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
```

- [ ] **步骤 10：实现 END_TAG_OPEN、SELF_CLOSING 状态**

- [ ] **步骤 11：运行测试确认通过**

- [ ] **步骤 12：编写属性引号测试**

```cpp
TEST(Tokenizer, AttributeDoubleQuoted) {
    Tokenizer t(R"(<a href="http://example.com?a=1&b=2">)");
    Token tok = t.next();
    EXPECT_EQ(tok.type, TokenType::START_TAG);
    EXPECT_EQ(tok.tag_name, "a");
    // 属性中包含 > 和 & 不应被误解析
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
```

- [ ] **步骤 13：实现 ATTR_VALUE_DOUBLE_Q、ATTR_VALUE_SINGLE_Q、ATTR_VALUE_UNQUOTED 状态**

- [ ] **步骤 14：运行测试确认通过**

- [ ] **步骤 15：编写防御性测试**

```cpp
TEST(Tokenizer, AngleBracketInText) {
    Tokenizer t("3 < 5");
    Token tok = t.next();
    EXPECT_EQ(tok.type, TokenType::TEXT);
    // "< 5" 中 < 后跟空格不是数字，应被视为标签开始或文本
    // 取决于实现："< 5" 中 < 后跟空格不是合法标签名
    // 预期行为：整个 "3 " 作为 TEXT，"< 5>" 或类似作为 TEXT
}

TEST(Tokenizer, UnclosedTagAtEOF) {
    Tokenizer t("text<unclosed");
    Token tok1 = t.next();
    EXPECT_EQ(tok1.type, TokenType::TEXT);
    EXPECT_EQ(tok1.raw, "text");
    ASSERT_TRUE(t.has_next());
    Token tok2 = t.next();
    // 未闭合的 <，将剩余作为 TEXT 或 START_TAG
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
```

- [ ] **步骤 16：实现 COMMENT、COMMENT_DASH1、COMMENT_DASH2、RAWTEXT 状态**

- [ ] **步骤 17：运行全部 Tokenizer 测试确认通过**

```bash
./build/tests/test_tokenizer
```

- [ ] **步骤 18：Commit**

```bash
git add core/src/tokenizer.h core/src/tokenizer.cpp tests/test_tokenizer.cpp
git commit -m "feat: 实现 Tokenizer 词法分析器（状态机 + 零拷贝 + 注释/脚本跳过）"
```

---

## 任务 3：TreeBuilder 栈式 AST 构建器

**文件：**
- 创建：`core/src/tree_builder.h`
- 创建：`core/src/tree_builder.cpp`
- 创建：`tests/test_tree_builder.cpp`

- [ ] **步骤 1：编写 tree_builder.h 内部头文件**

```cpp
#pragma once

#include "tokenizer.h"
#include <vector>
#include <string>
#include <string_view>

namespace xmarkup {

struct ASTNode {
    enum Type { ROOT, ELEMENT, TEXT };
    Type                 type;
    std::string_view     tag_name;     // ELEMENT 时有效
    std::string_view     attributes;   // ELEMENT 时有效
    std::string_view     text;         // TEXT 时有效（指向原始 HTML）
    std::vector<ASTNode> children;
};

class TreeBuilder {
public:
    explicit TreeBuilder(uint16_t max_depth = 256, bool autocorrect = true);

    ASTNode build(const std::vector<Token>& tokens);

private:
    bool is_void_element(std::string_view tag) const;
    void handle_start_tag(const Token& tok, ASTNode& root);
    void handle_end_tag(const Token& tok, ASTNode& root);
    void handle_self_closing(const Token& tok, ASTNode& root);
    void autocorrect_misnested(std::string_view tag);

    uint16_t max_depth_;
    bool autocorrect_;

    // 构建状态
    std::vector<ASTNode*> stack_;
};

} // namespace xmarkup
```

- [ ] **步骤 2：编写正常嵌套测试**

```cpp
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
    ASSERT_EQ(root.children.size(), 3u);  // ELEMENT(b), TEXT(""), ELEMENT(i) 或 ELEMENT(b), ELEMENT(i)
    EXPECT_EQ(root.children[0].tag_name, "b");
    // 具体结构取决于空白文本节点是否保留
}
```

- [ ] **步骤 3：运行测试确认失败**

- [ ] **步骤 4：实现 TreeBuilder 的 build 方法和栈操作**

实现核心逻辑：遍历 Token 序列，START_TAG 压栈，END_TAG 弹栈，TEXT 作为叶子节点。void 元素不压栈。

- [ ] **步骤 5：运行测试确认通过**

- [ ] **步骤 6：编写自动纠错测试**

```cpp
TEST_F(TreeBuilderTest, MisnestedTags) {
    auto root = parse("<a><b></a></b>");
    // 纠错后: <a><b></b></a><b></b>
    // 或等效结构
    ASSERT_GE(root.children.size(), 2u);
    // 第一个子树：<a> 包含 <b>
    // 第二个子树：<b>
}

TEST_F(TreeBuilderTest, UnclosedTags) {
    auto root = parse("<div><p>text");
    // 末尾自动补齐 </p></div>
    ASSERT_EQ(root.children.size(), 1u);
    auto& div = root.children[0];
    EXPECT_EQ(div.tag_name, "div");
    auto& p = div.children[0];
    EXPECT_EQ(p.tag_name, "p");
}

TEST_F(TreeBuilderTest, ExtraCloseTag) {
    auto root = parse("</b>text");
    // </b> 被忽略，text 保留
    ASSERT_GE(root.children.size(), 1u);
}

TEST_F(TreeBuilderTest, VoidElementNotStacked) {
    auto root = parse("before<br>after");
    // <br> 作为叶子节点，不入栈
    // 验证结构：TEXT("before"), ELEMENT("br"), TEXT("after")
}
```

- [ ] **步骤 7：实现自动纠错逻辑（栈中查找匹配、隐式闭合、重开）**

- [ ] **步骤 8：运行测试确认通过**

- [ ] **步骤 9：编写嵌套深度限制测试**

```cpp
TEST_F(TreeBuilderTest, MaxNestingDepth) {
    std::string html;
    for (int i = 0; i < 300; i++) html += "<div>";
    html += "text";
    TreeBuilder builder(256, true);
    Tokenizer tok(html.c_str());
    std::vector<Token> tokens;
    while (tok.has_next()) tokens.push_back(tok.next());
    auto root = builder.build(tokens);
    // 不崩溃，文本保留，深度截断
    EXPECT_GT(root.children.size(), 0u);
}
```

- [ ] **步骤 10：运行全部 TreeBuilder 测试确认通过**

```bash
./build/tests/test_tree_builder
```

- [ ] **步骤 11：Commit**

```bash
git add core/src/tree_builder.h core/src/tree_builder.cpp tests/test_tree_builder.cpp
git commit -m "feat: 实现 TreeBuilder 栈式 AST 构建器（自动纠错 + 深度限制）"
```

---

## 任务 4：EntityDecoder HTML 实体解码器

**文件：**
- 创建：`core/src/entity_decoder.h`
- 创建：`core/src/entity_decoder.cpp`
- 创建：`tests/test_entity_decoder.cpp`

- [ ] **步骤 1：编写 entity_decoder.h 内部头文件**

```cpp
#pragma once

#include <string>
#include <string_view>

namespace xmarkup {

class EntityDecoder {
public:
    // 解码 HTML 实体，返回解码后的字符串
    static std::string decode(std::string_view text);

private:
    static bool try_decode_entity(std::string_view text, size_t pos,
                                   size_t& entity_end, std::string& decoded);
    static bool try_named_entity(std::string_view name, std::string& decoded);
    static bool try_numeric_entity(std::string_view value, bool is_hex,
                                    std::string& decoded);
};

} // namespace xmarkup
```

- [ ] **步骤 2：编写命名实体测试**

```cpp
#include <gtest/gtest.h>
#include "entity_decoder.h"

using namespace xmarkup;

TEST(EntityDecoder, NamedEntities) {
    EXPECT_EQ(EntityDecoder::decode("&amp;"), "&");
    EXPECT_EQ(EntityDecoder::decode("&lt;"), "<");
    EXPECT_EQ(EntityDecoder::decode("&gt;"), ">");
    EXPECT_EQ(EntityDecoder::decode("&quot;"), "\"");
    EXPECT_EQ(EntityDecoder::decode("&apos;"), "'");
    EXPECT_EQ(EntityDecoder::decode("&nbsp;"), "\xC2\xA0");
}

TEST(EntityDecoder, NumericDecimal) {
    EXPECT_EQ(EntityDecoder::decode("&#60;"), "<");
    EXPECT_EQ(EntityDecoder::decode("&#20013;"), "\xe4\xb8\xad"); // "中"
}

TEST(EntityDecoder, NumericHex) {
    EXPECT_EQ(EntityDecoder::decode("&#x3c;"), "<");
    EXPECT_EQ(EntityDecoder::decode("&#x4e2d;"), "\xe4\xb8\xad"); // "中"
}

TEST(EntityDecoder, MixedText) {
    EXPECT_EQ(EntityDecoder::decode("1 &lt; 2 &amp; 3 &gt; 0"), "1 < 2 & 3 > 0");
}

TEST(EntityDecoder, IncompleteEntity) {
    EXPECT_EQ(EntityDecoder::decode("&amp hello"), "& hello");
    EXPECT_EQ(EntityDecoder::decode("&unknown;"), "&unknown;");
}

TEST(EntityDecoder, NoEntities) {
    EXPECT_EQ(EntityDecoder::decode("plain text"), "plain text");
}

TEST(EntityDecoder, EmptyInput) {
    EXPECT_EQ(EntityDecoder::decode(""), "");
}
```

- [ ] **步骤 3：运行测试确认失败**

- [ ] **步骤 4：实现 EntityDecoder**

核心逻辑：
1. 遍历字符串，遇到 `&` 开始解析
2. 如果后续是 `#` 开头，尝试数字实体
3. 如果后续是 `#x` 开头，尝试十六进制实体
4. 否则尝试命名实体（查 `unordered_map`）
5. 找到 `;` 结束实体引用
6. 解码失败时保留原始 `&` 及后续字符

内置约 120 个常用命名实体映射表（amp、lt、gt、quot、apos、nbsp、copy、reg、trade、mdash、ndash、laquo、raquo 等）。

- [ ] **步骤 5：运行测试确认通过**

```bash
./build/tests/test_entity_decoder
```

- [ ] **步骤 6：Commit**

```bash
git add core/src/entity_decoder.h core/src/entity_decoder.cpp tests/test_entity_decoder.cpp
git commit -m "feat: 实现 EntityDecoder HTML 实体解码器（命名/数字/十六进制实体）"
```

---

## 任务 5：StyleResolver 样式解析器

**文件：**
- 创建：`core/src/style_resolver.h`
- 创建：`core/src/style_resolver.cpp`
- 创建：`tests/test_style_resolver.cpp`

- [ ] **步骤 1：编写 style_resolver.h 内部头文件**

```cpp
#pragma once

#include "tree_builder.h"
#include "entity_decoder.h"
#include <vector>
#include <string>
#include <string_view>

namespace xmarkup {

struct InternalSpan {
    uint32_t    byte_start;
    uint32_t    byte_end;
    int         tag;       // XMTagType 值
    int         style;     // XMStyleType 值，0 表示无样式
    std::string value;     // 拷贝的值字符串（因为需要跨 string_view 生命周期）
};

struct FlattenResult {
    std::string              text;   // 解码后的纯文本
    std::vector<InternalSpan> spans; // 基于 byte offset 的样式区间
};

class StyleResolver {
public:
    explicit StyleResolver(uint16_t base_font_size = 16);

    FlattenResult resolve(const ASTNode& root);

private:
    void dfs(const ASTNode& node, bool inside_pre);
    int map_tag(std::string_view tag_name) const;
    void parse_inline_style(std::string_view style_str);
    void extract_attribute_value(std::string_view attrs, const char* attr_name,
                                  std::string& out_value) const;
    std::string normalize_color(std::string_view value) const;
    std::string normalize_font_size(std::string_view value) const;
    std::string normalize_font_weight(std::string_view value) const;

    uint16_t base_font_size_;
    FlattenResult result_;
    std::vector<std::string_view> parent_stack_;
    uint32_t byte_offset_ = 0;
};

} // namespace xmarkup
```

- [ ] **步骤 2：编写标签映射测试**

```cpp
#include <gtest/gtest.h>
#include "style_resolver.h"
#include "tokenizer.h"
#include "tree_builder.h"

using namespace xmarkup;

class StyleResolverTest : public ::testing::Test {
protected:
    FlattenResult resolve(const char* html) {
        Tokenizer tok(html);
        std::vector<Token> tokens;
        while (tok.has_next()) tokens.push_back(tok.next());
        TreeBuilder tb;
        auto ast = tb.build(tokens);
        StyleResolver sr;
        return sr.resolve(ast);
    }
};

TEST_F(StyleResolverTest, BoldTag) {
    auto r = resolve("<b>bold</b>");
    EXPECT_EQ(r.text, "bold");
    ASSERT_EQ(r.spans.size(), 1u);
    EXPECT_EQ(r.spans[0].tag, 1); // XM_TAG_BOLD
    EXPECT_EQ(r.spans[0].byte_start, 0u);
    EXPECT_EQ(r.spans[0].byte_end, 4u);
}

TEST_F(StyleResolverTest, StrongMapsToBold) {
    auto r = resolve("<strong>bold</strong>");
    EXPECT_EQ(r.text, "bold");
    ASSERT_EQ(r.spans.size(), 1u);
    EXPECT_EQ(r.spans[0].tag, 1); // XM_TAG_BOLD，与 <b> 相同
}

TEST_F(StyleResolverTest, NestedStyleStacking) {
    auto r = resolve("<b><i>text</i></b>");
    EXPECT_EQ(r.text, "text");
    ASSERT_EQ(r.spans.size(), 2u);
    EXPECT_EQ(r.spans[0].tag, 1); // XM_TAG_BOLD
    EXPECT_EQ(r.spans[1].tag, 2); // XM_TAG_ITALIC
}

TEST_F(StyleResolverTest, InlineStyleColor) {
    auto r = resolve(R"(<b style="color:#ff0000">text</b>)");
    EXPECT_EQ(r.text, "text");
    ASSERT_GE(r.spans.size(), 2u);
    // 第一个 span: XM_TAG_BOLD
    // 第二个 span: XM_STYLE_FOREGROUND_COLOR = "#FF0000"
}
```

- [ ] **步骤 3：运行测试确认失败**

- [ ] **步骤 4：实现 StyleResolver 的 DFS 遍历和标签映射**

核心逻辑：
1. DFS 遍历 AST，维护 `parent_stack_`
2. TEXT 节点：解码 HTML 实体（调用 `EntityDecoder::decode`），追加到 `result_.text`，更新 `byte_offset_`。非 `<pre>` 内折叠空白
3. ELEMENT 节点：映射 `tag_name` → `XMTagType`，记录 span。解析 `style` 属性。对于 `<a>` 提取 `href`，对于 `<img>` 提取 `src`，对于 `<source>` 查询父标签栈
4. 标签映射使用 `std::unordered_map<std::string_view, int>`

- [ ] **步骤 5：运行测试确认通过**

- [ ] **步骤 6：编写 CSS 解析测试**

```cpp
TEST_F(StyleResolverTest, CSSColorName) {
    auto r = resolve(R"(<span style="color:red">text</span>)");
    ASSERT_GE(r.spans.size(), 2u);
    // 找到 FOREGROUND_COLOR span
    bool found = false;
    for (auto& s : r.spans) {
        if (s.style == 1 && s.value == "#FF0000") found = true; // XM_STYLE_FOREGROUND_COLOR
    }
    EXPECT_TRUE(found);
}

TEST_F(StyleResolverTest, CSSFontSizePx) {
    auto r = resolve(R"(<span style="font-size:16px">text</span>)");
    bool found = false;
    for (auto& s : r.spans) {
        if (s.style == 3 && s.value == "16") found = true; // XM_STYLE_FONT_SIZE
    }
    EXPECT_TRUE(found);
}

TEST_F(StyleResolverTest, CSSFontSizeEm) {
    StyleResolver sr(16); // base_font_size = 16
    auto r = resolve(R"(<span style="font-size:1.5em">text</span>)");
    bool found = false;
    for (auto& s : r.spans) {
        if (s.style == 3 && s.value == "24") found = true;
    }
    EXPECT_TRUE(found);
}
```

- [ ] **步骤 7：实现 CSS 行内样式解析和值标准化**

- [ ] **步骤 8：运行测试确认通过**

- [ ] **步骤 9：编写 source 上下文感知测试**

```cpp
TEST_F(StyleResolverTest, SourceInVideoContext) {
    auto r = resolve("<video><source src=\"a.mp4\" type=\"video/mp4\"></video>");
    bool found_video_source = false;
    for (auto& s : r.spans) {
        if (s.tag == 43) found_video_source = true; // XM_TAG_VIDEO_SOURCE
    }
    EXPECT_TRUE(found_video_source);
}

TEST_F(StyleResolverTest, SourceInAudioContext) {
    auto r = resolve("<audio><source src=\"a.mp3\" type=\"audio/mpeg\"></audio>");
    bool found_audio_source = false;
    for (auto& s : r.spans) {
        if (s.tag == 45) found_audio_source = true; // XM_TAG_AUDIO_SOURCE
    }
    EXPECT_TRUE(found_audio_source);
}
```

- [ ] **步骤 10：运行全部 StyleResolver 测试确认通过**

```bash
./build/tests/test_style_resolver
```

- [ ] **步骤 11：Commit**

```bash
git add core/src/style_resolver.h core/src/style_resolver.cpp tests/test_style_resolver.cpp
git commit -m "feat: 实现 StyleResolver 样式解析器（标签映射 + CSS 解析 + 父标签栈）"
```

---

## 任务 6：UTF16Indexer UTF-16 索引映射器

**文件：**
- 创建：`core/src/utf16_indexer.h`
- 创建：`core/src/utf16_indexer.cpp`
- 创建：`tests/test_utf16_indexer.cpp`

- [ ] **步骤 1：编写 utf16_indexer.h 内部头文件**

```cpp
#pragma once

#include <cstdint>
#include <string_view>
#include <vector>

namespace xmarkup {

struct ByteToUTF16 {
    uint32_t byte_offset;
    uint32_t utf16_offset;
};

class UTF16Indexer {
public:
    void build(std::string_view utf8_text);
    uint32_t byte_to_utf16(uint32_t byte_offset) const;

private:
    std::vector<ByteToUTF16> mapping_;
};

} // namespace xmarkup
```

- [ ] **步骤 2：编写测试**

```cpp
#include <gtest/gtest.h>
#include "utf16_indexer.h"

using namespace xmarkup;

TEST(UTF16Indexer, PureASCII) {
    UTF16Indexer idx;
    idx.build("Hello");
    EXPECT_EQ(idx.byte_to_utf16(0), 0u);
    EXPECT_EQ(idx.byte_to_utf16(3), 3u);
    EXPECT_EQ(idx.byte_to_utf16(5), 5u);
}

TEST(UTF16Indexer, ChineseCharacters) {
    // "你好" = 6 UTF-8 bytes, 2 UTF-16 code units
    UTF16Indexer idx;
    idx.build("\xe4\xbd\xa0\xe5\xa5\xbd"); // "你好"
    EXPECT_EQ(idx.byte_to_utf16(0), 0u);
    EXPECT_EQ(idx.byte_to_utf16(3), 1u);  // "好" starts at UTF-16 index 1
    EXPECT_EQ(idx.byte_to_utf16(6), 2u);  // end
}

TEST(UTF16Indexer, Emoji) {
    // "😊" = 4 UTF-8 bytes, 2 UTF-16 code units (surrogate pair)
    UTF16Indexer idx;
    idx.build("\xf0\x9f\x98\x8a"); // "😊"
    EXPECT_EQ(idx.byte_to_utf16(0), 0u);
    EXPECT_EQ(idx.byte_to_utf16(4), 2u);  // surrogate pair = 2 UTF-16 units
}

TEST(UTF16Indexer, MixedContent) {
    // "Hi你好😊" = 2+6+4 = 12 bytes, 2+2+2 = 6 UTF-16 units
    UTF16Indexer idx;
    idx.build("Hi\xe4\xbd\xa0\xe5\xa5\xbd\xf0\x9f\x98\x8a");
    EXPECT_EQ(idx.byte_to_utf16(0), 0u);   // H
    EXPECT_EQ(idx.byte_to_utf16(2), 2u);   // 你 start
    EXPECT_EQ(idx.byte_to_utf16(8), 4u);   // 😊 start
    EXPECT_EQ(idx.byte_to_utf16(12), 6u);  // end
}

TEST(UTF16Indexer, EmptyString) {
    UTF16Indexer idx;
    idx.build("");
    EXPECT_EQ(idx.byte_to_utf16(0), 0u);
}
```

- [ ] **步骤 3：运行测试确认失败**

- [ ] **步骤 4：实现 UTF16Indexer**

核心逻辑：
1. 单趟扫描 UTF-8 字符串
2. 根据首字节判断 UTF-8 序列长度（1/2/3/4 字节）
3. 计算对应的 UTF-16 码元数（1 字节→1，2/3 字节→1，4 字节→2 即 surrogate pair）
4. 在序列长度变化处记录锚点
5. 查询时用 `std::lower_bound` 二分查找

- [ ] **步骤 5：运行测试确认通过**

```bash
./build/tests/test_utf16_indexer
```

- [ ] **步骤 6：Commit**

```bash
git add core/src/utf16_indexer.h core/src/utf16_indexer.cpp tests/test_utf16_indexer.cpp
git commit -m "feat: 实现 UTF16Indexer UTF-8→UTF-16 索引映射器"
```

---

## 任务 7：Parser 内部编排 + C API 封装

**文件：**
- 创建：`core/src/parser.h`
- 创建：`core/src/parser.cpp`
- 创建：`core/src/api.cpp`

- [ ] **步骤 1：编写 parser.h 内部头文件**

```cpp
#pragma once

#include "tokenizer.h"
#include "tree_builder.h"
#include "style_resolver.h"
#include "utf16_indexer.h"
#include "xmarkup/xmarkup.h"
#include <string>
#include <vector>

namespace xmarkup {

struct ParserInternal {
    XMConfig config;
    XMError last_error = XM_OK;

    XMResult* parse(const char* html, size_t length);
private:
    std::string owned_text_;
    std::vector<XMSpan> owned_spans_;
    std::vector<std::string> owned_values_; // 管理 value 字符串生命周期
};

} // namespace xmarkup
```

- [ ] **步骤 2：实现 parser.cpp 完整管线**

`ParserInternal::parse()` 编排：
1. 创建 `Tokenizer`，收集所有 Token
2. 创建 `TreeBuilder`，构建 AST
3. 创建 `StyleResolver`，DFS 展平得到 `FlattenResult`（含解码后文本 + byte offset spans）
4. 创建 `UTF16Indexer`，对 `FlattenResult.text` 做索引映射
5. 将 `InternalSpan` 的 byte offset 转换为 UTF-16 索引
6. 组装 `XMResult`，拷贝所有数据到 `XMResult` 所有权中

- [ ] **步骤 3：实现 api.cpp extern "C" 封装**

```cpp
#include "parser.h"
#include "xmarkup/xmarkup.h"
#include <cstdlib>
#include <cstring>

extern "C" {

XMParser* xmarkup_create(const XMConfig* config) {
    XMConfig cfg = {1, 256, 16}; // 默认值
    if (config) cfg = *config;
    auto* p = new (std::nothrow) xmarkup::ParserInternal();
    if (!p) return nullptr;
    p->config = cfg;
    return reinterpret_cast<XMParser*>(p);
}

void xmarkup_destroy(XMParser* parser) {
    delete reinterpret_cast<xmarkup::ParserInternal*>(parser);
}

XMResult* xmarkup_parse(XMParser* parser, const char* html, size_t length) {
    if (!parser) return nullptr;
    auto* p = reinterpret_cast<xmarkup::ParserInternal*>(parser);
    return p->parse(html, length);
}

void xmarkup_result_free(XMResult* result) {
    if (!result) return;
    // 释放 result 内部动态分配的内存
    delete[] result->text;
    delete[] result->spans;
    // value 字符串的释放策略需要根据实现调整
    delete result;
}

XMError xmarkup_last_error(XMParser* parser) {
    if (!parser) return XM_ERR_NULL_PARSER;
    return reinterpret_cast<xmarkup::ParserInternal*>(parser)->last_error;
}

const char* xmarkup_error_string(XMError error) {
    switch (error) {
        case XM_OK: return "Success";
        case XM_ERR_NULL_PARSER: return "Parser is NULL";
        case XM_ERR_NULL_INPUT: return "Input HTML is NULL";
        case XM_ERR_NESTING_OVERFLOW: return "Nesting depth overflow, truncated";
        case XM_ERR_ALLOC_FAILED: return "Memory allocation failed";
        default: return "Unknown error";
    }
}

} // extern "C"
```

- [ ] **步骤 4：运行全部构建确认编译通过**

```bash
cmake --build build
```

- [ ] **步骤 5：Commit**

```bash
git add core/src/parser.h core/src/parser.cpp core/src/api.cpp
git commit -m "feat: 实现 Parser 管线编排和 extern C API 封装"
```

---

## 任务 8：API 集成测试（完整管线验证）

**文件：**
- 修改：`tests/test_api.cpp`

- [ ] **步骤 1：编写基本管线测试**

```cpp
#include <gtest/gtest.h>
#include "xmarkup/xmarkup.h"

class APITest : public ::testing::Test {
protected:
    void SetUp() override {
        XMConfig cfg = {1, 256, 16};
        parser_ = xmarkup_create(&cfg);
        ASSERT_NE(parser_, nullptr);
    }
    void TearDown() override {
        if (parser_) xmarkup_destroy(parser_);
    }
    XMParser* parser_ = nullptr;
};

TEST_F(APITest, SimpleBold) {
    const char* html = "<b>bold</b>";
    auto* result = xmarkup_parse(parser_, html, strlen(html));
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
    auto* result = xmarkup_parse(parser_, "", 0);
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
```

- [ ] **步骤 2：运行测试确认基本管线工作**

```bash
cmake --build build && ./build/tests/test_api --gtest_filter=APITest.SimpleBold
```

- [ ] **步骤 3：逐步添加规格第 11 章的契约测试**

按 11.1~11.10 的每个示例添加测试用例。每个测试的预期输出直接来自规格文档。至少覆盖以下场景：

- 文本样式：`<b>`, `<i>`, `<u>`, `<s>`, `<mark>`, `<code>`, `<sub>`, `<sup>`, 嵌套叠加, 标签+CSS 叠加
- 段落结构：`<p>`, `<h1>`~`<h6>`, `<blockquote>`, `<pre>`, `<div>`, `<span>`
- 链接媒体：`<a href>`, `<img>`, `<video>` + `<source>`, `<audio>`
- 列表：`<ul><li>`, `<ol><li>`, 嵌套列表
- 表格：`<table><tr><td><th>`
- 特殊：`<br>`, `<hr>`, 未知标签
- 纠错：乱序嵌套、未闭合、多余闭合
- 实体：命名实体、数字实体、容错
- CSS 标准化：颜色名/rgb/hex, font-size 单位换算

- [ ] **步骤 4：运行全部 API 集成测试**

```bash
./build/tests/test_api
```

预期：所有契约测试 PASS。如果某个失败，修复对应模块。

- [ ] **步骤 5：Commit**

```bash
git add tests/test_api.cpp
git commit -m "test: 添加完整管线集成测试（覆盖规格第 11 章全部契约）"
```

---

## 任务 9：性能 + 压力 + 线程安全测试

**文件：**
- 修改：`tests/test_api.cpp`
- 创建：`tests/test_data/stress_50kb.html`
- 创建：`tests/test_data/malicious.html`

- [ ] **步骤 1：生成 50KB 压力测试 HTML 文件**

编写一个小脚本或直接嵌入一个 `std::string` 生成器，生成约 50KB 的包含各种标签和样式的 HTML：

```cpp
TEST_F(APITest, Stress50KB) {
    // 生成约 50KB 的 HTML
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
    EXPECT_LT(ms, 15) << "50KB 解析耗时 " << ms << "ms，超出 15ms 目标";

    xmarkup_result_free(result);
}
```

- [ ] **步骤 2：生成恶意构造 HTML 测试**

```cpp
TEST_F(APITest, MaliciousDeepNesting) {
    std::string html;
    for (int i = 0; i < 10000; i++) html += "<div>";
    html += "text";
    EXPECT_NO_FATAL_FAILURE({
        auto* result = xmarkup_parse(parser_, html.c_str(), html.size());
        ASSERT_NE(result, nullptr);
        EXPECT_EQ(result->error, XM_ERR_NESTING_OVERFLOW);
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
```

- [ ] **步骤 3：编写线程安全测试**

```cpp
TEST_F(APITest, ThreadSafety) {
    const char* html = "<b><i style=\"color:red\">text</i></b>";
    constexpr int num_threads = 8;
    std::vector<std::thread> threads;
    std::atomic<int> errors{0};

    for (int t = 0; t < num_threads; t++) {
        threads.emplace_back([&]() {
            XMConfig cfg = {1, 256, 16};
            XMParser* p = xmarkup_create(&cfg);
            for (int i = 0; i < 100; i++) {
                auto* result = xmarkup_parse(p, html, strlen(html));
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
```

- [ ] **步骤 4：运行全部测试确认通过**

```bash
cmake --build build
./build/tests/test_api
cd build && ctest --output-on-failure
```

- [ ] **步骤 5：Commit**

```bash
git add tests/test_api.cpp tests/test_data/
git commit -m "test: 添加性能压力测试、恶意输入测试和线程安全测试"
```

---

## 任务 10：全量测试验证 + 文档更新

- [ ] **步骤 1：运行全部测试套件**

```bash
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
cd build && ctest --output-on-failure
```

预期：全部 6 个测试可执行文件（test_tokenizer, test_tree_builder, test_style_resolver, test_entity_decoder, test_utf16_indexer, test_api）100% PASS。

- [ ] **步骤 2：检查二进制体积**

```bash
ls -lh build/core/libxmarkup_core.a
```

预期：小于 500KB。

- [ ] **步骤 3：用 ASAN 运行测试**

```bash
cmake -B build-asan -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_CXX_FLAGS="-fsanitize=address,undefined -fno-omit-frame-pointer"
cmake --build build-asan
cd build-asan && ctest --output-on-failure
```

预期：全部 PASS，无 ASAN 报错。

- [ ] **步骤 4：更新设计规格文档状态**

将 `docs/superpowers/specs/2026-06-05-xmarkup-core-design.md` 头部状态从"待用户审查"改为"已通过审查，实现完成"。

- [ ] **步骤 5：Final Commit**

```bash
git add docs/
git commit -m "docs: 更新设计规格状态为已实现"
```
