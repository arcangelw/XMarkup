# XMarkup C++ 核心库 Code Review 修复计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 修复 Code Review 发现的安全性、正确性和代码质量问题

**架构：** 保持现有五阶段管线不变，修复 parser.cpp 的 UB、style_resolver.cpp 的溢出和误判、tokenizer.cpp 的大小写支持，清理死代码和冗余逻辑

**技术栈：** C++17, CMake, GoogleTest

---

## 文件变更清单

| 文件 | 操作 | 职责变更 |
|------|------|----------|
| `core/src/parser.cpp` | 修改 | 修复 null+0 输入的 UB |
| `core/src/style_resolver.cpp` | 修改 | 修复 rgb() 溢出、background 简写误判、normalize_font_size 多小数点 |
| `core/src/style_resolver.h` | 修改 | 删除 `parse_inline_style` 声明 |
| `core/src/tokenizer.cpp` | 修改 | 添加小写化 tag_name、修复冗余条件、删除死代码状态处理 |
| `core/src/tokenizer.h` | 修改 | 删除死代码状态枚举、未使用方法声明 |
| `core/src/tree_builder.h` | 修改 | 删除未使用的 `root_` 成员 |
| `core/src/tree_builder.cpp` | 修改 | 删除未使用的 `autocorrect_misnested` 方法、添加指针安全性注释 |
| `core/src/api.cpp` | 修改 | 修复矛盾注释 |
| `core/src/entity_decoder.cpp` | 修改 | 删除重复 `cedil` 条目 |
| `tests/test_api.cpp` | 修改 | 新增 null+0 输入测试、大写标签测试 |
| `tests/test_style_resolver.cpp` | 修改 | 新增 rgb() 溢出测试、background 简写测试 |
| `tests/test_tokenizer.cpp` | 修改 | 新增大写标签 Tokenizer 测试 |

---

### 任务 1：修复 parser.cpp 中 null+0 输入的未定义行为

**文件：**
- 修改：`core/src/parser.cpp:32-37`
- 测试：`tests/test_api.cpp`

**问题：** `html == nullptr && length == 0` 时不会触发 `XM_ERR_NULL_INPUT`，但后续 `std::string_view(nullptr, 0)` 是 C++17 UB。

- [ ] **步骤 1：编写失败的测试**

在 `tests/test_api.cpp` 末尾（`VersionString` 测试之前）添加：

```cpp
TEST_F(APITest, NullHtmlWithZeroLength) {
    auto* result = xmarkup_parse(parser_, nullptr, 0);
    ASSERT_NE(result, nullptr);
    EXPECT_EQ(result->error, XM_OK);
    EXPECT_NE(result->text, nullptr);
    EXPECT_EQ(result->span_count, 0u);
    xmarkup_result_free(result);
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`cd /Users/arcangelw/GitHub/XMarkup/build && cmake --build . && ./tests/test_api --gtest_filter='*NullHtmlWithZeroLength*'`
预期：通过（当前实现在大多数平台不会崩溃，但 UBSan 会报错）

- [ ] **步骤 3：修复 parser.cpp**

```cpp
// parser.cpp:32-46，替换原有输入校验
XMResult* ParserInternal::parse(const char* html, size_t length) {
    last_error = XM_OK;
    owned_text_.clear();
    owned_spans_.clear();
    owned_values_.clear();

    // 空/null 输入：返回空结果（不触发 UB）
    if (!html || length == 0) {
        auto* result = new (std::nothrow) XMResult();
        if (!result) {
            last_error = XM_ERR_ALLOC_FAILED;
            return nullptr;
        }
        result->error = XM_OK;
        result->text = "";
        result->text_len = 0;
        result->spans = nullptr;
        result->span_count = 0;
        return result;
    }

    // 阶段 1：词法分析
    std::string_view html_view(html, length);
    // ... 后续代码不变
```

注意：`result->text = ""` 使用字符串字面量，生命周期全局有效，无需 owned_text_ 管理。

- [ ] **步骤 4：运行全量测试确认无回归**

运行：`cd /Users/arcangelw/GitHub/XMarkup/build && cmake --build . && ctest --output-on-failure`
预期：全部通过

- [ ] **步骤 5：Commit**

```bash
git add core/src/parser.cpp tests/test_api.cpp
git commit -m "fix(core): 修复 html=nullptr+length=0 时 string_view 构造的未定义行为"
```

---

### 任务 2：修复 style_resolver.cpp 中 normalize_color rgb() 整数溢出

**文件：**
- 修改：`core/src/style_resolver.cpp:374-380`
- 测试：`tests/test_style_resolver.cpp`

- [ ] **步骤 1：编写失败的测试**

在 `tests/test_style_resolver.cpp` 末尾添加：

```cpp
TEST_F(StyleResolverTest, CSSColorRgbOverflow) {
    // rgb() 中的超大值应被钳位到 [0,255]，不崩溃不产生垃圾值
    auto r = resolve(R"(<span style="color:rgb(9999999999,0,0)">text</span>)");
    bool found = false;
    for (auto& s : r.spans) {
        if (s.style == XM_STYLE_FOREGROUND_COLOR) {
            found = true;
            // 值应该是有效的 #RRGGBB 格式（钳位后为 #FF0000）
            EXPECT_EQ(s.value.substr(0, 1), "#");
            EXPECT_EQ(s.value.size(), 7u);
        }
    }
    EXPECT_TRUE(found);
}

TEST_F(StyleResolverTest, CSSColorRgbNegative) {
    auto r = resolve(R"(<span style="color:rgb(-1,128,256)">text</span>)");
    bool found = false;
    for (auto& s : r.spans) {
        if (s.style == XM_STYLE_FOREGROUND_COLOR) {
            found = true;
            EXPECT_EQ(s.value.substr(0, 1), "#");
        }
    }
    EXPECT_TRUE(found);
}
```

- [ ] **步骤 2：运行测试验证行为**

运行：`cd /Users/arcangelw/GitHub/XMarkup/build && cmake --build . && ./tests/test_style_resolver --gtest_filter='*RgbOverflow*:*RgbNegative*'`

- [ ] **步骤 3：修复 normalize_color 中的 parse_int**

替换 `core/src/style_resolver.cpp` 中 `normalize_color` 方法内的 `parse_int` lambda（约第 374-380 行）：

```cpp
auto parse_int = [&](size_t& p) -> int {
    // 处理负数前缀
    bool negative = false;
    if (p < value.size() && value[p] == '-') {
        negative = true;
        p++;
    }
    int v = 0;
    bool overflow = false;
    while (p < value.size() && value[p] >= '0' && value[p] <= '9') {
        if (!overflow) {
            int digit = value[p] - '0';
            if (v > (255 - digit) / 10) {
                overflow = true;
                v = 255;
            } else {
                v = v * 10 + digit;
            }
        }
        p++;
    }
    if (negative) return 0;
    return std::min(v, 255);
};
```

同时将 `r = parse_int(start)` / `g = parse_int(start)` / `b = parse_int(start)` 之后的 snprintf 调用确认无误（`%02X` 已经只取低 8 位，所以即使有微小溢出也安全，但钳位更严谨）。

- [ ] **步骤 4：运行全量测试**

运行：`cd /Users/arcangelw/GitHub/XMarkup/build && cmake --build . && ctest --output-on-failure`
预期：全部通过

- [ ] **步骤 5：Commit**

```bash
git add core/src/style_resolver.cpp tests/test_style_resolver.cpp
git commit -m "fix(core): 修复 normalize_color rgb() 解析整数溢出，钳位到 [0,255]"
```

---

### 任务 3：修复 normalize_font_size 多小数点处理

**文件：**
- 修改：`core/src/style_resolver.cpp:415-463`

- [ ] **步骤 1：编写测试**

在 `tests/test_style_resolver.cpp` 末尾添加：

```cpp
TEST_F(StyleResolverTest, CSSFontSizeMultipleDots) {
    // "1.2.3px" —— 遇到第二个 '.' 停止解析，视为无效
    auto r = resolve(R"(<span style="font-size:1.2.3px">text</span>)");
    EXPECT_EQ(r.text, "text");
    // 不应产生 fontSize span（或产生合理值）
}
```

- [ ] **步骤 2：修复 normalize_font_size**

在 `core/src/style_resolver.cpp` 的 `normalize_font_size` 方法中，替换数值提取循环（约第 423-433 行）：

```cpp
double num = 0;
size_t i = 0;
bool has_dot = false;
double frac = 0.1;
while (i < value.size() && ((value[i] >= '0' && value[i] <= '9') || value[i] == '.')) {
    if (value[i] == '.') {
        if (has_dot) break;  // 第二个小数点，停止解析
        has_dot = true;
    } else if (!has_dot) {
        num = num * 10 + (value[i] - '0');
    } else {
        num += (value[i] - '0') * frac;
        frac *= 0.1;
    }
    i++;
}
```

- [ ] **步骤 3：运行测试**

运行：`cd /Users/arcangelw/GitHub/XMarkup/build && cmake --build . && ctest --output-on-failure`
预期：全部通过

- [ ] **步骤 4：Commit**

```bash
git add core/src/style_resolver.cpp tests/test_style_resolver.cpp
git commit -m "fix(core): normalize_font_size 遇到第二个小数点时停止解析"
```

---

### 任务 4：修复 background 简写属性误判为颜色

**文件：**
- 修改：`core/src/style_resolver.cpp:253`
- 测试：`tests/test_style_resolver.cpp`

- [ ] **步骤 1：编写测试**

```cpp
TEST_F(StyleResolverTest, CSSBackgroundShorthand) {
    // background 简写含 url() 不应产生 backgroundColor span
    auto r = resolve(R"(<span style="background:url(bg.png) no-repeat">text</span>)");
    for (auto& s : r.spans) {
        EXPECT_NE(s.style, XM_STYLE_BACKGROUND_COLOR)
            << "background 简写含 url() 不应产生 backgroundColor span";
    }
}

TEST_F(StyleResolverTest, CSSBackgroundColorNamed) {
    auto r = resolve(R"(<span style="background-color:red">text</span>)");
    bool found = false;
    for (auto& s : r.spans) {
        if (s.style == XM_STYLE_BACKGROUND_COLOR && s.value == "#FF0000") found = true;
    }
    EXPECT_TRUE(found);
}
```

- [ ] **步骤 2：修复 add_style_spans**

在 `core/src/style_resolver.cpp` 的 `add_style_spans` 方法中，修改 `background` 属性的处理（约第 253 行）：

```cpp
} else if (prop == "background-color") {
    style_type = XM_STYLE_BACKGROUND_COLOR;
    normalized_value = normalize_color(val);
} else if (prop == "background") {
    // background 是简写属性，仅提取颜色值（跳过 url()、gradient 等）
    if (val.find("url(") == std::string::npos &&
        val.find("linear-gradient(") == std::string::npos &&
        val.find("radial-gradient(") == std::string::npos) {
        style_type = XM_STYLE_BACKGROUND_COLOR;
        normalized_value = normalize_color(val);
    }
}
```

- [ ] **步骤 3：运行测试**

运行：`cd /Users/arcangelw/GitHub/XMarkup/build && cmake --build . && ctest --output-on-failure`
预期：全部通过

- [ ] **步骤 4：Commit**

```bash
git add core/src/style_resolver.cpp tests/test_style_resolver.cpp
git commit -m "fix(core): background 简写属性排除 url/gradient 值避免误判颜色"
```

---

### 任务 5：添加 HTML 标签名大小写不敏感支持

**文件：**
- 修改：`core/src/tokenizer.h:49`（Token.tag_name 类型不变，但 Tokenizer 内部处理小写化）
- 修改：`core/src/tokenizer.cpp:103-108`（TAG_NAME 状态添加小写化）
- 测试：`tests/test_tokenizer.cpp`, `tests/test_api.cpp`

**设计决策：** 在 Tokenizer 层小写化 tag_name（`string_view → string` 拷贝），而非在 StyleResolver 层做 case-insensitive 查找。理由：Token.tag_name 只用于标签匹配，小写化一次后所有下游消费者都受益，且 Tokenizer 的 string_view → string 开销仅在标签名上（通常很短），不影响大量文本内容。

- [ ] **步骤 1：修改 Token 结构支持 owned tag_name**

`core/src/tokenizer.h` 修改 `Token` 结构：

```cpp
struct Token {
    TokenType        type;
    std::string_view raw;
    std::string      owned_tag_name;  // 小写化后的标签名（owned，用于标签匹配）
    std::string_view tag_name;        // 指向 owned_tag_name（标签匹配用）
    std::string_view attributes;
};
```

- [ ] **步骤 2：修改 Tokenizer TAG_NAME 状态**

在 `core/src/tokenizer.cpp` 的 TAG_NAME 状态中（约第 103-108 行），读取完 tag_name 后添加小写化：

```cpp
// 读取标签名（到空白、'>' 或 '/' 为止）
size_t name_start = pos_;
while (pos_ < html_.size() && !is_whitespace(html_[pos_]) &&
       html_[pos_] != '>' && html_[pos_] != '/') {
    pos_++;
}
std::string_view raw_tag = html_.substr(name_start, pos_ - name_start);
if (raw_tag.empty()) {
    state_ = TokenizerState::DATA;
    break;
}

// 小写化标签名（HTML 标签名不区分大小写）
std::string tag_lower;
tag_lower.reserve(raw_tag.size());
for (char c : raw_tag) {
    tag_lower += static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
}
```

然后将所有 `tag_name` 使用处改为从 `tag_lower` 构造 Token：

在 `emit_tag_token` 标签和 EOF 标签产出时：

```cpp
tok.owned_tag_name = std::move(tag_lower);
tok.tag_name = tok.owned_tag_name;
```

注意：`emit_tag_token` 和 EOF 回退两处都需要修改。`tag_name` 变量（`std::string_view`）需要改为 `tag_lower`（`std::string`）。

- [ ] **步骤 3：编写测试**

在 `tests/test_tokenizer.cpp` 末尾添加：

```cpp
TEST(Tokenizer, UppercaseTag) {
    Tokenizer t("<DIV>content</DIV>");
    std::vector<Token> tokens;
    while (t.has_next()) tokens.push_back(t.next());
    ASSERT_GE(tokens.size(), 4u);
    EXPECT_EQ(tokens[0].type, TokenType::START_TAG);
    EXPECT_EQ(tokens[0].tag_name, "div");  // 小写化
    EXPECT_EQ(tokens[2].type, TokenType::END_TAG);
    EXPECT_EQ(tokens[2].tag_name, "div");
}

TEST(Tokenizer, MixedCaseTag) {
    Tokenizer t("<StrOnG>bold</StRoNg>");
    std::vector<Token> tokens;
    while (t.has_next()) tokens.push_back(t.next());
    ASSERT_GE(tokens.size(), 4u);
    EXPECT_EQ(tokens[0].tag_name, "strong");
    EXPECT_EQ(tokens[2].tag_name, "strong");
}
```

在 `tests/test_api.cpp` 末尾添加：

```cpp
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
```

- [ ] **步骤 4：运行测试**

运行：`cd /Users/arcangelw/GitHub/XMarkup/build && cmake --build . && ctest --output-on-failure`
预期：全部通过

- [ ] **步骤 5：Commit**

```bash
git add core/src/tokenizer.h core/src/tokenizer.cpp tests/test_tokenizer.cpp tests/test_api.cpp
git commit -m "feat(core): HTML 标签名大小写不敏感，Tokenizer 层小写化"
```

---

### 任务 6：清理死代码和未使用成员

**文件：**
- 修改：`core/src/tree_builder.h`（删除 `root_` 成员）
- 修改：`core/src/tree_builder.cpp`（删除 `autocorrect_misnested` 方法）
- 修改：`core/src/style_resolver.h`（删除 `parse_inline_style` 声明）
- 修改：`core/src/style_resolver.cpp`（删除 `parse_inline_style` 空实现）
- 修改：`core/src/tokenizer.h`（删除 `COMMENT_DASH1/COMMENT_DASH2/RAWTEXT` 状态枚举、`advance/peek` 方法声明）
- 修改：`core/src/tokenizer.cpp`（删除 `advance/peek` 实现、COMMENT_DASH1/2/RAWTEXT case 分支）

- [ ] **步骤 1：删除 tree_builder.h 中 root_ 成员**

`core/src/tree_builder.h`：
- 删除第 79 行 `ASTNode root_;` 及其注释

```cpp
// 删除前：
    uint16_t max_depth_;
    bool autocorrect_;
    std::vector<ASTNode*> stack_;
    ASTNode root_;               /**< 根节点（build 调用间复用） */

// 删除后：
    uint16_t max_depth_;
    bool autocorrect_;
    std::vector<ASTNode*> stack_;
```

- [ ] **步骤 2：删除 tree_builder.cpp 中 autocorrect_misnested 方法**

删除 `core/src/tree_builder.cpp:142-151` 整个方法实现：

```cpp
// 删除以下代码：
void TreeBuilder::autocorrect_misnested(std::string_view tag) {
    for (auto it = stack_.rbegin(); it != stack_.rend() - 1; ++it) {
        if ((*it)->tag_name == tag) {
            auto depth = stack_.rend() - it;
            stack_.resize(static_cast<size_t>(depth));
            return;
        }
    }
}
```

同时从 `tree_builder.h` 中删除对应声明：

```cpp
// 删除：
    /** @brief 纠正错嵌套标签 */
    void autocorrect_misnested(std::string_view tag);
```

- [ ] **步骤 3：删除 style_resolver 的 parse_inline_style**

从 `core/src/style_resolver.h` 删除声明（约第 82-83 行）：

```cpp
// 删除：
    /** @brief 解析内联 style 属性（已弃用，由 add_style_spans 替代） */
    void parse_inline_style(std::string_view style_str);
```

从 `core/src/style_resolver.cpp` 删除实现（第 297-299 行）：

```cpp
// 删除：
void StyleResolver::parse_inline_style(std::string_view) {
    // 已由 add_style_spans 处理，此方法保留为空
}
```

- [ ] **步骤 4：删除 tokenizer 死代码状态和方法**

`core/src/tokenizer.h`：
- 删除枚举中的 `COMMENT_DASH1`, `COMMENT_DASH2`, `RAWTEXT`（第 38-40 行）
- 删除 `advance()` 和 `peek()` 方法声明（第 89-91 行）

```cpp
// 枚举改为：
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
};

// 删除 private 方法声明：
// char advance();
// char peek() const;
```

`core/src/tokenizer.cpp`：
- 删除 `COMMENT_DASH1/COMMENT_DASH2/RAWTEXT` 的 case 分支（第 343-350 行）
- 删除 `advance()` 和 `peek()` 方法实现（第 361-368 行）

- [ ] **步骤 5：运行全量测试**

运行：`cd /Users/arcangelw/GitHub/XMarkup/build && cmake --build . && ctest --output-on-failure`
预期：全部通过

- [ ] **步骤 6：Commit**

```bash
git add core/src/tree_builder.h core/src/tree_builder.cpp core/src/style_resolver.h core/src/style_resolver.cpp core/src/tokenizer.h core/src/tokenizer.cpp
git commit -m "refactor(core): 清理死代码 — 删除未使用的 root_/autocorrect_misnested/parse_inline_style/advance/peek 及废弃状态枚举"
```

---

### 任务 7：修复 api.cpp 矛盾注释 + entity_decoder.cpp 重复条目 + tokenizer 冗余条件

**文件：**
- 修改：`core/src/api.cpp:53-60`
- 修改：`core/src/entity_decoder.cpp:78`
- 修改：`core/src/tokenizer.cpp:325`

- [ ] **步骤 1：修复 api.cpp 注释**

替换 `core/src/api.cpp:53-60`：

```cpp
void xmarkup_result_free(XMResult* result) {
    // XMResult 中的 text/spans/value 指针由 ParserInternal 的 owned_* 成员管理，
    // 此处仅释放 XMResult 结构体本身。
    if (result) delete result;
}
```

- [ ] **步骤 2：删除 entity_decoder.cpp 重复 cedil**

在 `core/src/entity_decoder.cpp` 中找到第 78 行的重复 `{"cedil", "\xC2\xB8"}` 并删除。两个 `cedil` 条目在同一行（第 78 行），只需保留一个：

```cpp
// 修改前（第 77-79 行）：
{"not", "\xC2\xAC"}, {"brvbar", "\xC2\xA6"}, {"cedil", "\xC2\xB8"},
{"uml", "\xC2\xA8"}, {"circ", "\xCB\x86"}, {"tilde", "\xCB\x9C"},
{"ring", "\xCB\x9A"}, {"cedil", "\xC2\xB8"},   ← 删除这个

// 修改后：
{"not", "\xC2\xAC"}, {"brvbar", "\xC2\xA6"}, {"cedil", "\xC2\xB8"},
{"uml", "\xC2\xA8"}, {"circ", "\xCB\x86"}, {"tilde", "\xCB\x9C"},
{"ring", "\xCB\x9A"},
```

- [ ] **步骤 3：修复 tokenizer.cpp COMMENT 冗余条件**

替换 `core/src/tokenizer.cpp:325`：

```cpp
// 修改前：
if (pos_ + 2 >= html_.size() && !(pos_ + 2 < html_.size())) {
    pos_ = html_.size();
}

// 修改后：
if (pos_ + 2 >= html_.size()) {
    pos_ = html_.size();
}
```

- [ ] **步骤 4：运行全量测试**

运行：`cd /Users/arcangelw/GitHub/XMarkup/build && cmake --build . && ctest --output-on-failure`
预期：全部通过

- [ ] **步骤 5：Commit**

```bash
git add core/src/api.cpp core/src/entity_decoder.cpp core/src/tokenizer.cpp
git commit -m "fix(core): 清理矛盾注释、重复实体条目和冗余条件判断"
```

---

### 任务 8：添加 TreeBuilder 指针安全性不变式注释

**文件：**
- 修改：`core/src/tree_builder.h:78`

- [ ] **步骤 1：添加安全性注释**

在 `core/src/tree_builder.h` 的 `stack_` 成员声明上方添加详细注释：

```cpp
    /**
     * 节点栈，管理当前嵌套路径。
     *
     * 指针安全性不变式：
     * stack_ 中存储的是指向 AST 节点（parent->children 中的元素）的裸指针。
     * 这些指针在 parent 的 children vector realloc 时会失效。
     *
     * 当前实现保证安全的条件：
     * - handle_start_tag() 只在 stack_.back() 的 children 中添加新节点
     * - 新节点成为新的 stack_.back()，栈中没有指向同一 parent children 中已有元素的指针
     * - 未闭合标签不会触发 parent children 的 realloc（新标签成为未闭合标签的子节点）
     *
     * ⚠️ 如果未来实现 HTML5 隐式关闭（如 <p> 遇到 <p> 时自动关闭前一个），
     * 需要重新审视此不变式——此时新标签会添加到更上层的 parent 而非当前栈顶，
     * 可能触发中间层 parent 的 children vector realloc，导致栈中指针悬空。
     * 届时建议改用 stable_vector 或索引方案替代裸指针。
     */
    std::vector<ASTNode*> stack_;
```

- [ ] **步骤 2：Commit**

```bash
git add core/src/tree_builder.h
git commit -m "docs(core): 添加 TreeBuilder stack_ 裸指针安全性不变式注释"
```
