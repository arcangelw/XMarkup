# Core C++ Code Review 修复计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:executing-plans（内联执行）逐任务实现此计划。步骤使用复选框（`- [ ]`）跟踪进度。

**目标：** 修复 2026-06-13 全量 code review 发现的 Core C++ 缺陷（3 个正确性 Bug + 2 个健壮性加固 + 1 处文档化 + 1 组代码质量清理），全部 TDD，最终 239+ 测试在 ASan 下全绿。

**架构：** 仅改动 `core/` 与 `tests/`，不动公共 ABI（`XMRange`/`XMSpan` 字段宽度不变）。修复集中在 `style_resolver.cpp`（实体解码、CSS 大小写、hex alpha）、`tree_builder.cpp`（迭代器加固）、`parser.cpp`（reserve）、`tokenizer.{h,cpp}`（static 化）、`xmarkup.h`（文档）。

**技术栈：** C++17 / CMake / GoogleTest 1.14 / `-Wall -Wextra -Wpedantic -Werror` / ASan（`build-asan/`）

---

## 基线

- 分支：`fix/core-cpp-review-fixes`（从 `main` 创建）
- 构建：`cmake --build build-asan -j`
- 测试：`cd build-asan/tests && ctest --output-on-failure`（**注意**：顶层 `CTestTestfile.cmake` 为空，必须在 `build-asan/tests/` 下执行 ctest）
- 基线状态：**239/239 通过**

## 文件结构

| 文件 | 改动 |
|------|------|
| `core/src/style_resolver.cpp` | 任务 1/2/3/5/7：实体解码、CSS 属性名小写、background 大小写、hex 8 位 alpha、变量改名 |
| `core/src/tree_builder.cpp` | 任务 4：`perform_implicit_close` / `handle_end_tag` 改索引循环 |
| `core/src/tokenizer.h` `core/src/tokenizer.cpp` | 任务 7：`is_alpha`/`is_whitespace` 转 `static` + goto 注释 |
| `core/src/parser.cpp` | 任务 7：`tokens.reserve` |
| `core/include/xmarkup/xmarkup.h` | 任务 6：4 GiB 上限文档化 |
| `tests/test_style_resolver.cpp` | 任务 1/2/3/5：回归测试 |
| `tests/test_tree_builder.cpp` | 任务 4：加固后行为回归（依赖现有用例） |

> **不在本次范围**：`#7 数字解析统一`（review 🟡#7）为重构而非 Bug，单独验证风险高，留作后续技术债；`#6 uint32→uint64` 会破坏公共结构体 ABI（影响 Swift 绑定），本次仅文档化上限并在入口不拦截（实际不会出现 4 GiB HTML）。

---

## 任务 1：属性值 HTML 实体解码（🔴 必须）

**文件：**
- 修改：`core/src/style_resolver.cpp:536-548`（`extract_attribute_value` 的两处赋值后 `return`）
- 测试：`tests/test_style_resolver.cpp`（追加）

- [ ] **步骤 1：写失败测试**（追加到 `test_style_resolver.cpp` 末尾）

```cpp
// ============================================================
// Code Review 修复：属性值 HTML 实体解码（🔴#1）
// ============================================================

TEST_F(StyleResolverTest, AttributeValueEntityDecodingHref) {
    // href 中的 &amp; 应解码为 &
    auto r = resolve("<a href=\"search?q=1&amp;page=2\">link</a>");
    bool found = false;
    for (auto& s : r.spans) {
        if (s.tag == XM_TAG_LINK) {
            found = true;
            EXPECT_EQ(s.value, "search?q=1&page=2") << "&amp; 应解码为 &";
        }
    }
    EXPECT_TRUE(found);
}

TEST_F(StyleResolverTest, AttributeValueEntityDecodingNumeric) {
    // 数字实体 &#x26; → '&'
    auto r = resolve("<a href=\"x&#x26;y\">link</a>");
    bool found = false;
    for (auto& s : r.spans) {
        if (s.tag == XM_TAG_LINK) {
            found = true;
            EXPECT_EQ(s.value, "x&y");
        }
    }
    EXPECT_TRUE(found);
}

TEST_F(StyleResolverTest, AttributeValueEntityDecodingImgSrc) {
    auto r = resolve("<img src=\"a&nbsp;b.png\">");
    for (auto& s : r.spans) {
        if (s.tag == XM_TAG_IMAGE) {
            EXPECT_EQ(s.value, "a\xC2\xA0""b.png") << "&nbsp; 应解码为 U+00A0";
        }
    }
}
```

- [ ] **步骤 2：验证失败**

```
cmake --build build-asan -j && (cd build-asan/tests && ctest -R AttributeValueEntity --output-on-failure)
```
预期：3 个新测试 FAIL（value 仍含字面 `&amp;` / `&#x26;` / `&nbsp;`）

- [ ] **步骤 3：实现**（`extract_attribute_value` 两处赋值后、`return` 前各加一行）

```cpp
        // 属性值中的 HTML 实体应解码（HTML5 §12.2.5.5 字符引用）
        out_value = EntityDecoder::decode(out_value);
        return;
```
> `entity_decoder.h` 已在 `style_resolver.cpp:2` 引入，无需新 include。

- [ ] **步骤 4：验证通过**

```
cmake --build build-asan -j && (cd build-asan/tests && ctest -R AttributeValueEntity --output-on-failure)
```
预期：3 PASS

- [ ] **步骤 5：commit**

```bash
git add core/src/style_resolver.cpp tests/test_style_resolver.cpp
git commit -m "fix(core): 属性值解码 HTML 实体（href/src/style 等）"
```

---

## 任务 2：CSS 属性名大小写不敏感（🔴 必须）

**文件：**
- 修改：`core/src/style_resolver.cpp:390-392`（`add_style_spans` 的 `prop` 计算后）
- 测试：`tests/test_style_resolver.cpp`

- [ ] **步骤 1：写失败测试**

```cpp
// ============================================================
// Code Review 修复：CSS 属性名大小写不敏感（🔴#2）
// ============================================================

TEST_F(StyleResolverTest, CSSPropertyNameUpperCase) {
    auto r = resolve(R"raw(<span STYLE="COLOR:RED">text</span>)raw");
    bool found = false;
    for (auto& s : r.spans) {
        if (s.style == XM_STYLE_FOREGROUND_COLOR && s.value == "#FF0000") found = true;
    }
    EXPECT_TRUE(found) << "STYLE=\"COLOR:RED\" 应识别为前景色";
}

TEST_F(StyleResolverTest, CSSPropertyNameMixedCaseFontSize) {
    auto r = resolve(R"(<span style="Font-Size:16px">text</span>)");
    bool found = false;
    for (auto& s : r.spans) {
        if (s.style == XM_STYLE_FONT_SIZE && s.value == "16") found = true;
    }
    EXPECT_TRUE(found);
}

TEST_F(StyleResolverTest, CSSPropertyNameUpperCaseTextAlign) {
    auto r = resolve(R"(<p style="TEXT-ALIGN:center">text</p>)");
    bool found = false;
    for (auto& s : r.spans) {
        if (s.style == XM_STYLE_TEXT_ALIGN && s.value == "center") found = true;
    }
    EXPECT_TRUE(found);
}
```

- [ ] **步骤 2：验证失败**

```
cmake --build build-asan -j && (cd build-asan/tests && ctest -R CSSPropertyName --output-on-failure)
```
预期：3 FAIL

- [ ] **步骤 3：实现**（`prop` 去尾部空白之后、`pos++` 跳过 `:` 之前）

```cpp
        std::string prop = style_str.substr(name_start, pos - name_start);
        // 去尾部空白
        while (!prop.empty() && isspace(static_cast<unsigned char>(prop.back()))) prop.pop_back();
        // CSS 属性名大小写不敏感（CSS 规范），统一小写化以便比较
        for (auto& c : prop) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
        pos++; // 跳过 ':'
```

- [ ] **步骤 4：验证通过**

```
cmake --build build-asan -j && (cd build-asan/tests && ctest -R CSSPropertyName --output-on-failure)
```
预期：3 PASS

- [ ] **步骤 5：commit**

```bash
git add core/src/style_resolver.cpp tests/test_style_resolver.cpp
git commit -m "fix(core): CSS 属性名大小写不敏感（COLOR/Font-Size 等可识别）"
```

---

## 任务 3：background 简写 url()/gradient() 大小写（🔴 必须）

**文件：**
- 修改：`core/src/style_resolver.cpp:428-435`（`add_style_spans` 的 `background` 分支）
- 测试：`tests/test_style_resolver.cpp`

- [ ] **步骤 1：写失败测试**

```cpp
// ============================================================
// Code Review 修复：background 简写 url()/gradient() 大小写不敏感（🔴#3）
// ============================================================

TEST_F(StyleResolverTest, CSSBackgroundShorthandUrlUpperCase) {
    auto r = resolve(R"html(<span style="background:URL(bg.png)">text</span>)html");
    for (auto& s : r.spans) {
        EXPECT_NE(s.style, XM_STYLE_BACKGROUND_COLOR)
            << "background:URL(...) 不应产生 backgroundColor span";
    }
}

TEST_F(StyleResolverTest, CSSBackgroundShorthandGradientMixedCase) {
    auto r = resolve(R"html(<span style="background:Linear-Gradient(to right, red, blue)">text</span>)html");
    for (auto& s : r.spans) {
        EXPECT_NE(s.style, XM_STYLE_BACKGROUND_COLOR)
            << "background:Linear-Gradient(...) 不应产生 backgroundColor span";
    }
}
```

- [ ] **步骤 2：验证失败**

```
cmake --build build-asan -j && (cd build-asan/tests && ctest -R CSSBackgroundShorthand --output-on-failure)
```
预期：2 FAIL（`CSSBackgroundShorthandWithUrl` 原有小写用例仍通过，新大写用例失败）

- [ ] **步骤 3：实现**

```cpp
        } else if (prop == "background") {
            // 大小写不敏感地检测 url()/gradient()：CSS 函数名不区分大小写
            std::string lower_val;
            lower_val.reserve(val.size());
            for (char c : val) lower_val += static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
            if (lower_val.find("url(") == std::string::npos &&
                lower_val.find("linear-gradient(") == std::string::npos &&
                lower_val.find("radial-gradient(") == std::string::npos &&
                lower_val.find("conic-gradient(") == std::string::npos) {
                style_type = XM_STYLE_BACKGROUND_COLOR;
                normalized_value = normalize_color(val);
            }
        }
```

- [ ] **步骤 4：验证通过**

```
cmake --build build-asan -j && (cd build-asan/tests && ctest -R CSSBackground --output-on-failure)
```
预期：全部 PASS（含原有 `CSSBackgroundShorthandWithUrl`）

- [ ] **步骤 5：commit**

```bash
git add core/src/style_resolver.cpp tests/test_style_resolver.cpp
git commit -m "fix(core): background 简写 url()/gradient() 大小写不敏感检测"
```

---

## 任务 4：tree_builder 迭代器加固（🟡 建议）

**文件：**
- 修改：`core/src/tree_builder.cpp:135-161`（`perform_implicit_close`）、`core/src/tree_builder.cpp:337-356`（`handle_end_tag`）
- 测试：依赖现有 `tests/test_tree_builder.cpp` 回归（行为不变，仅消除 `rend()-1` 在空 vector 上的 UB 隐患）

- [ ] **步骤 1：实现 `perform_implicit_close`**（reverse_iterator → 索引循环 + 空栈守卫）

```cpp
void TreeBuilder::perform_implicit_close(const std::string& new_tag) {
    // 不变式：stack_ 非空，栈底 stack_[0] 为 ROOT，不参与隐式关闭。
    // 用索引循环替代 reverse_iterator + rend()-1（后者在空 vector 上为 UB）。
    if (stack_.size() <= 1) return; // 仅 ROOT，无可隐式关闭的元素

    size_t pop_count = 0;
    bool found = false;
    for (size_t idx = stack_.size() - 1; idx > 0; --idx) {
        const auto& parent_tag = stack_[idx]->tag_name;

        if (should_auto_close(parent_tag, new_tag)) {
            Logger::warn("implicit close: <%s> closed by <%s>", parent_tag.c_str(), new_tag.c_str());
            found = true;
            break;
        }
        if (is_scope_boundary(parent_tag)) {
            Logger::trace("implicit scan: scope boundary <%s> stops scan", parent_tag.c_str());
            break;
        }
        pop_count++;
    }

    if (found) {
        stack_.resize(stack_.size() - pop_count - 1);
    }
}
```

- [ ] **步骤 2：实现 `handle_end_tag`**（同样改索引循环）

```cpp
void TreeBuilder::handle_end_tag(const Token& tok) {
    if (stack_.size() <= 1) {
        // 栈只剩 ROOT，多余的闭合标签忽略
        return;
    }

    size_t pop_count = 0;
    bool found = false;
    for (size_t idx = stack_.size() - 1; idx > 0; --idx) {
        pop_count++;
        if (stack_[idx]->tag_name == tok.tag_name) {
            found = true;
            break;
        }
    }

    if (found) {
        stack_.resize(stack_.size() - pop_count);
        return;
    }

    // 未找到匹配，多余的闭合标签忽略
    Logger::warn("extra close tag ignored: </%s>", tok.tag_name.c_str());
}
```

- [ ] **步骤 3：回归验证**

```
cmake --build build-asan -j && (cd build-asan/tests && ctest -R "TreeBuilder|StyleResolver" --output-on-failure)
```
预期：全部 PASS（隐式关闭、adoption、未闭合补齐等行为不变）

- [ ] **步骤 4：commit**

```bash
git add core/src/tree_builder.cpp
git commit -m "refactor(core): tree_builder 用索引循环替代 rend()-1，消除空栈 UB 隐患"
```

---

## 任务 5：hex 颜色 8 位 alpha 处理（🟡 建议）

**文件：**
- 修改：`core/src/style_resolver.cpp:556-568`（`normalize_color` 的 `'#'` 分支）
- 测试：`tests/test_style_resolver.cpp`

- [ ] **步骤 1：写失败测试**

```cpp
// ============================================================
// Code Review 修复：hex 颜色 8 位 alpha 处理（🟡#5）
// ============================================================

TEST_F(StyleResolverTest, CSSColorHex8AlphaStripped) {
    // #RRGGBBAA 应截取 RGB 部分（与 rgba 丢 alpha 行为一致）
    auto r = resolve(R"(<span style="color:#FF0000FF">text</span>)");
    bool found = false;
    for (auto& s : r.spans) {
        if (s.style == XM_STYLE_FOREGROUND_COLOR && s.value == "#FF0000") found = true;
    }
    EXPECT_TRUE(found) << "#FF0000FF 应取 RGB 部分 #FF0000";
}

TEST_F(StyleResolverTest, CSSColorHex8AlphaLowerStripped) {
    auto r = resolve(R"(<span style="color:#00ff0080">text</span>)");
    bool found = false;
    for (auto& s : r.spans) {
        if (s.style == XM_STYLE_FOREGROUND_COLOR && s.value == "#00FF00") found = true;
    }
    EXPECT_TRUE(found);
}
```

- [ ] **步骤 2：验证失败**

```
cmake --build build-asan -j && (cd build-asan/tests && ctest -R CSSColorHex8 --output-on-failure)
```
预期：2 FAIL（当前返回 `#FF0000FF` 整串）

- [ ] **步骤 3：实现**（`'#'` 分支内，`size()==4` 之后加 `size()==9`）

```cpp
    if (value[0] == '#') {
        std::string result(value);
        if (result.size() == 4) {
            // #RGB → #RRGGBB
            result = "#";
            result += value[1]; result += value[1];
            result += value[2]; result += value[2];
            result += value[3]; result += value[3];
        } else if (result.size() == 9) {
            // #RRGGBBAA → #RRGGBB（丢弃 alpha，与 rgba/hsla 丢 alpha 行为一致）
            result = result.substr(0, 7);
        }
        // 转大写
        for (auto& c : result) { if (c >= 'a' && c <= 'f') c -= 32; }
        return result;
    }
```

- [ ] **步骤 4：验证通过**

```
cmake --build build-asan -j && (cd build-asan/tests && ctest -R "CSSColorHex8|CSSColorHex" --output-on-failure)
```
预期：全部 PASS（含原有 `CSSColorHex`）

- [ ] **步骤 5：commit**

```bash
git add core/src/style_resolver.cpp tests/test_style_resolver.cpp
git commit -m "fix(core): normalize_color 支持 8 位 hex (#RRGGBBAA) 截取 RGB"
```

---

## 任务 6：uint32 4 GiB 上限文档化（📝 仅文档）

**文件：** `core/include/xmarkup/xmarkup.h`

- [ ] **步骤 1：实现**（`XMRange` 与 `XMResult.text_len` 注释各加一行 `@warning`）

`XMRange` 注释追加：
```c
 * @warning start/end 为 uint32_t，文本上限约 4 GiB（UTF-16 单元）。超出时索引回绕，
 *          当前设计不处理超长输入（实际 HTML 不会达到此量级）。
```

`XMResult.text_len` 字段注释追加：
```c
    uint32_t      text_len;   /**< text 的字节长度（不含终止符）。上限约 4 GiB（uint32_t）。 */
```

- [ ] **步骤 2：验证编译**（仅注释变更，`-Werror` 下须确认无 warning）

```
cmake --build build-asan -j 2>&1 | tail -3
```
预期：`Built target xmarkup_core`，无 warning

- [ ] **步骤 3：commit**

```bash
git add core/include/xmarkup/xmarkup.h
git commit -m "docs(core): 文档化 XMRange/text_len 的 4GiB 上限"
```

---

## 任务 7：代码质量清理（🟢 可选）

**文件：** `core/src/style_resolver.cpp`、`core/src/tokenizer.h`、`core/src/tokenizer.cpp`、`core/src/parser.cpp`

> 无新测试，靠现有 239 用例回归。

- [ ] **步骤 1：`style_resolver.cpp` 变量遮蔽改名**（`add_style_spans` 的 `!important` 块内 `start` → `lead`）

```cpp
            size_t lead = 0;
            while (lead < suffix.size() && (suffix[lead] == ' ' || suffix[lead] == '\t')) lead++;
            if (suffix.substr(lead) == "!important") {
```

- [ ] **步骤 2：`tokenizer.h` `is_alpha`/`is_whitespace` 声明改 `static`**

```cpp
    /** @brief 是否到达输入末尾 */
    bool is_eof() const;
    /** @brief 判断是否为 ASCII 字母 */
    static bool is_alpha(char c);
    /** @brief 判断是否为空白字符（空格、制表、换行、回车、换页） */
    static bool is_whitespace(char c);
```

- [ ] **步骤 3：`tokenizer.cpp` 定义去 `const`、加 `static` 对齐**

```cpp
bool Tokenizer::is_alpha(char c) {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
}

bool Tokenizer::is_whitespace(char c) {
    return c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\f';
}
```
（`is_eof` 保持 `const`）

- [ ] **步骤 4：`tokenizer.cpp` goto 处加注释**（`emit_tag_token` 与 EOF 回退两处回溯循环前）

```cpp
            // 回溯定位 '<'：由于进入 TAG_NAME 前已消费 '<'（开始标签在 name_start-1，
            // 结束标签在 name_start-2），回溯至多 2 步，O(1)。
            size_t lt_pos = name_start;
            while (lt_pos > 0 && html_[lt_pos - 1] != '<') lt_pos--;
```

- [ ] **步骤 5：`parser.cpp` tokens 预估 reserve**

```cpp
    std::vector<Token> tokens;
    tokens.reserve(length / 8 + 8); // 粗略预估，减少 realloc
    while (tokenizer.has_next()) {
        tokens.push_back(tokenizer.next());
    }
```

- [ ] **步骤 6：全量回归**

```
cmake --build build-asan -j && (cd build-asan/tests && ctest --output-on-failure | tail -5)
```
预期：239 + 任务 1/2/3/5 新增 ≈ 全部 PASS，0 failed

- [ ] **步骤 7：commit**

```bash
git add core/src/style_resolver.cpp core/src/tokenizer.h core/src/tokenizer.cpp core/src/parser.cpp
git commit -m "refactor(core): 清理变量遮蔽、is_alpha/is_whitespace static 化、tokens reserve、goto 注释"
```

---

## 任务 8：最终验证

- [ ] **步骤 1：全量构建 + 测试（ASan）**

```
cmake --build build-asan -j && (cd build-asan/tests && ctest --output-on-failure)
```
预期：`100% tests passed, 0 tests failed`，总数 = 239 + 新增（11 个：任务1×3 + 任务2×3 + 任务3×2 + 任务5×2 + 任务6 无测试... 实际新增 10）

- [ ] **步骤 2：ASan 无报错确认**

测试运行过程中无 `ERROR: AddressSanitizer` 输出。

- [ ] **步骤 3：提交链核对**

```
git log --oneline main..HEAD
```
预期：7 个 commit（任务 1-7 各一）

- [ ] **步骤 4：finishing-a-development-branch 收尾**

使用 superpowers:finishing-a-development-branch，向用户展示合并 / PR / 保留分支选项。

---

## 自检

- **规格覆盖度**：review 清单 🔴#1/#2/#3 → 任务 1/2/3；🟡#4/#5 → 任务 4/5；🟡#6 → 任务 6（文档化，理由：不改 ABI）；🟡#7 → 明确不在范围（重构留技术债）；🟢#8/#9/#10/#11/#12 → 任务 7。全覆盖。
- **占位符扫描**：无 TODO/待定，每个代码步骤含完整代码块。
- **类型一致性**：`EntityDecoder::decode(std::string_view)→std::string`、`extract_attribute_value(...,std::string& out_value)`、`Tokenizer::is_alpha(char)` 签名与现有一致。
