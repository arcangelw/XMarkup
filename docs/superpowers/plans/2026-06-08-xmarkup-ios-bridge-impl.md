# XMarkup iOS 桥接层 + 核心引擎改进 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 改进核心引擎（float 精度、占位字符、注释规范），然后构建 Swift 桥接层提供原始数据层 + NSAttributedString 便利层，支持 iOS 15+ / macOS 12+。

**架构：** 两阶段——阶段一在 `feat/core-engine-improvements` 分支改进 C++ 核心引擎（7 项），阶段二在 `feat/ios-bridge` 分支构建 SPM 双 target（CXMarkup + XMarkup）Swift 桥接层。

**技术栈：** C++17（核心引擎）/ Swift 6+ / Xcode 26+ / SPM / XCTest / GoogleTest v1.14.0

---

## 文件结构

### 阶段一：核心引擎改进（修改现有文件）

| 文件 | 职责 | 改动类型 |
|------|------|----------|
| `core/include/xmarkup/xmarkup.h` | 公共 C API 头文件 | `base_font_size` uint16→float、`xmarkup_version()` 声明、Doxygen 注释 |
| `core/src/style_resolver.h` | StyleResolver 内部头文件 | `base_font_size_` uint16→float、Doxygen 注释 |
| `core/src/style_resolver.cpp` | 样式解析实现 | float 换算、占位字符插入、命名常量、Doxygen + 逻辑注释 |
| `core/src/parser.h` | ParserInternal 内部头文件 | Doxygen 注释 |
| `core/src/parser.cpp` | 管线编排 | 适配 float config、Doxygen 注释 |
| `core/src/api.cpp` | extern "C" 封装 | 默认 config 适配 float、`xmarkup_version()` 实现、Doxygen 注释 |
| `core/src/tokenizer.h` | Tokenizer 内部头文件 | Doxygen 注释 |
| `core/src/tokenizer.cpp` | 词法分析实现 | 逻辑注释 |
| `core/src/tree_builder.h` | TreeBuilder 内部头文件 | Doxygen 注释 |
| `core/src/tree_builder.cpp` | AST 构建实现 | 命名常量、逻辑注释 |
| `core/src/entity_decoder.h` | EntityDecoder 内部头文件 | Doxygen 注释 |
| `core/src/entity_decoder.cpp` | 实体解码实现 | 来源注释 |
| `core/src/utf16_indexer.h` | UTF16Indexer 内部头文件 | Doxygen 注释 |
| `core/src/utf16_indexer.cpp` | UTF-16 索引映射实现 | 逻辑注释 |
| `tests/test_style_resolver.cpp` | StyleResolver 测试 | float 精度测试、占位字符测试、边界用例 |
| `tests/test_api.cpp` | API 集成测试 | float 端到端测试、占位字符测试、多语言测试、version 测试 |
| `tests/test_entity_decoder.cpp` | EntityDecoder 测试 | 边界用例补充 |
| `tests/test_tokenizer.cpp` | Tokenizer 测试 | 边界用例补充 |
| `tests/test_tree_builder.cpp` | TreeBuilder 测试 | 边界用例补充 |

### 阶段二：iOS 桥接层（新建文件）

| 文件 | 职责 |
|------|------|
| `Package.swift` | SPM 清单（CXMarkup + XMarkup 两个 target） |
| `platforms/ios/Sources/XMarkup/XMarkupError.swift` | 错误枚举 + `init(cError:)` |
| `platforms/ios/Sources/XMarkup/XMarkupTag.swift` | 标签枚举 + `init(cValue:)` |
| `platforms/ios/Sources/XMarkup/XMarkupStyle.swift` | CSS 样式枚举 + `init(cValue:)` |
| `platforms/ios/Sources/XMarkup/XMarkupSpan.swift` | 样式区间结构体 + C 结构转换 |
| `platforms/ios/Sources/XMarkup/XMarkupResult.swift` | 结果结构体 + `fromC()` 转换 |
| `platforms/ios/Sources/XMarkup/XMarkupParser.swift` | 解析器封装，生命周期管理 |
| `platforms/ios/Sources/XMarkup/PlatformTypes.swift` | 跨平台 XMFont/XMColor 公开 typealias |
| `platforms/ios/Sources/XMarkup/ColorParser.swift` | `#RRGGBB` → XMColor 解析工具 |
| `platforms/ios/Sources/XMarkup/NSAttributedString+XMarkup.swift` | 便利层：span→attribute 映射 |
| `platforms/ios/Tests/XMarkupTests/XMarkupParserTests.swift` | 解析器生命周期 + parse 正确性测试 |
| `platforms/ios/Tests/XMarkupTests/XMarkupResultTests.swift` | 结果转换测试 |
| `platforms/ios/Tests/XMarkupTests/NSAttributedStringTests.swift` | 便利层测试 |
| `platforms/ios/Tests/XMarkupTests/ColorParserTests.swift` | 颜色解析测试 |
| `platforms/ios/Tests/XMarkupTests/CrossPlatformTests.swift` | 跨平台编译验证 |
| `.swiftlint.yml` | SwiftLint 规则配置 |
| `.swiftformat` | SwiftFormat 规则配置 |

---

## 阶段一：核心引擎改进

分支：`feat/core-engine-improvements`（从 main 创建）

### 任务 1：base_font_size uint16 → float

**文件：**
- 修改：`core/include/xmarkup/xmarkup.h:108`
- 修改：`core/src/style_resolver.h:26,40`
- 修改：`core/src/style_resolver.cpp:47,379-393`
- 修改：`core/src/api.cpp:6`
- 测试：`tests/test_style_resolver.cpp`
- 测试：`tests/test_api.cpp:13,360`

- [ ] **步骤 1：编写失败的测试（float 精度验证）**

在 `tests/test_style_resolver.cpp` 末尾添加：

```cpp
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
            // 接受 "16" 或 "16.00" 都通过
            found = (s.value == "16" || s.value == "15.996" || s.value == "16.00");
        }
    }
    EXPECT_TRUE(found);
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`cd build && cmake --build . && cd tests && ctest -R StyleResolverTest -V`

预期：`CSSFontSizeFloatBase` 编译失败或运行失败（`uint16_t` 无法接受 `14.5f`，且 `normalize_font_size` 输出整数格式）

- [ ] **步骤 3：修改 xmarkup.h**

将 `core/include/xmarkup/xmarkup.h:108` 的 `uint16_t base_font_size` 改为 `float base_font_size`：

```cpp
/* 配置 */
typedef struct XMConfig {
    uint8_t  enable_autocorrect;
    uint16_t max_nesting_depth;
    float    base_font_size;       // 基准字号（px），支持浮点精度
} XMConfig;
```

- [ ] **步骤 4：修改 style_resolver.h**

```cpp
// 第 26 行：构造函数参数
explicit StyleResolver(float base_font_size = 16.0f);

// 第 40 行：成员变量
float base_font_size_;
```

- [ ] **步骤 5：修改 style_resolver.cpp**

构造函数（第 47 行）：
```cpp
StyleResolver::StyleResolver(float base_font_size)
    : base_font_size_(base_font_size) {}
```

`normalize_font_size()` 方法（替换第 351-394 行）：
```cpp
std::string StyleResolver::normalize_font_size(std::string_view value) const {
    if (value.empty()) return {};

    // 提取数值部分
    double num = 0;
    size_t i = 0;
    bool has_dot = false;
    double frac = 0.1;
    while (i < value.size() && ((value[i] >= '0' && value[i] <= '9') || value[i] == '.')) {
        if (value[i] == '.') {
            has_dot = true;
        } else if (!has_dot) {
            num = num * 10 + (value[i] - '0');
        } else {
            num += (value[i] - '0') * frac;
            frac *= 0.1;
        }
        i++;
    }

    // 检查单位
    std::string unit;
    while (i < value.size() && isalpha(static_cast<unsigned char>(value[i]))) {
        unit += static_cast<char>(tolower(static_cast<unsigned char>(value[i])));
        i++;
    }

    // 换算为 px（保留浮点精度）
    double px = num;
    if (unit == "em") {
        px = num * base_font_size_;
    } else if (unit == "rem") {
        px = num * base_font_size_;
    } else if (unit == "pt") {
        px = num * 1.333;
    } else if (unit == "%") {
        px = num * base_font_size_ / 100.0;
    }

    // 格式化：最多 2 位小数，去除尾部零
    char buf[32];
    std::snprintf(buf, sizeof(buf), "%.2f", px);
    std::string result(buf);
    // 去除尾部 '0'
    while (result.size() > 1 && result.back() == '0') result.pop_back();
    // 去除尾部 '.'
    if (result.size() > 1 && result.back() == '.') result.pop_back();
    return result;
}
```

- [ ] **步骤 6：修改 api.cpp 默认 config**

`core/src/api.cpp:6`：

```cpp
XMConfig cfg = {1, 256, 16.0f};
```

- [ ] **步骤 7：修复现有测试中的 config 初始化**

`tests/test_api.cpp:13` 中的 `XMConfig cfg = {1, 256, 16}` 改为 `XMConfig cfg = {1, 256, 16.0f}`。

`tests/test_api.cpp:360` 中的 `XMConfig cfg = {1, 256, 16}` 改为 `XMConfig cfg = {1, 256, 16.0f}`。

`tests/test_style_resolver.cpp:10` 中的 `uint16_t base_font_size = 16` 改为 `float base_font_size = 16.0f`。

- [ ] **步骤 8：运行全部测试验证通过**

运行：`cd build && cmake --build . && cd tests && ctest -V`

预期：所有 85+ 测试通过（含新增的 2 个 float 精度测试）

- [ ] **步骤 9：Commit**

```bash
git add -A
git commit -m "refactor: base_font_size 从 uint16 改为 float，支持浮点精度

- XMConfig.base_font_size 类型改为 float
- normalize_font_size 保留浮点精度输出（最多 2 位小数）
- 新增 CSSFontSizeFloatBase、CSSFontSizeFloatPt 测试"
```

---

### 任务 2：零长度 Tag 插入占位字符 + 段落分隔符验证

**文件：**
- 修改：`core/src/style_resolver.cpp:97-155`
- 测试：`tests/test_style_resolver.cpp`
- 测试：`tests/test_api.cpp`

- [ ] **步骤 1：编写失败的测试（占位字符）**

在 `tests/test_style_resolver.cpp` 末尾添加：

```cpp
TEST_F(StyleResolverTest, ImageInsertsPlaceholder) {
    auto r = resolve("Hello <img src=\"photo.jpg\"> World");
    // image 应插入 ￼ 占位字符，span range 非零
    bool found = false;
    for (auto& s : r.spans) {
        if (s.tag == XM_TAG_IMAGE) {
            found = true;
            EXPECT_GT(s.byte_start, 0u);
            EXPECT_GT(s.byte_end, s.byte_start); // range 非零长度
            EXPECT_FALSE(r.text.empty());
            // text 中应包含 \xEF\xBF\xBC (U+FFFC 的 UTF-8 编码)
            EXPECT_NE(r.text.find("\xEF\xBF\xBC"), std::string::npos);
        }
    }
    EXPECT_TRUE(found);
}

TEST_F(StyleResolverTest, LineBreakInsertsNewline) {
    auto r = resolve("before<br>after");
    // br 应插入 \n
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
```

- [ ] **步骤 2：运行测试验证失败**

运行：`cd build && cmake --build . && cd tests && ctest -R StyleResolver -V`

预期：`ImageInsertsPlaceholder` 和 `LineBreakInsertsNewline` 失败（当前 image/br 不产生文本，range 为零长度）

- [ ] **步骤 3：验证段落分隔符**

先运行一个快速测试确认段落行为：

```cpp
TEST_F(StyleResolverTest, ParagraphSeparation) {
    auto r = resolve("<p>First</p><p>Second</p>");
    // 两个段落之间应有分隔
    EXPECT_NE(r.text.find("First"), std::string::npos);
    EXPECT_NE(r.text.find("Second"), std::string::npos);
}
```

如果输出为 `FirstSecond`（无分隔），需要在 dfs() 的 ELEMENT 处理中，对 `<p>` 标签在子节点处理后追加 `\n`。

- [ ] **步骤 4：实现占位字符插入**

在 `core/src/style_resolver.cpp` 的 `dfs()` 方法中，ELEMENT 分支的子节点递归处理之后（第 146 行 `parent_stack_.pop_back()` 之后），添加占位字符逻辑：

```cpp
        // 弹出父标签栈
        parent_stack_.pop_back();

        // 为 void/empty 元素插入占位字符，使 span range 非零长度
        // ￼ = U+FFFC 对象替换字符 (UTF-8: EF BF BC)
        // \n = U+000A 换行符
        if (tag_type == XM_TAG_IMAGE || tag_type == XM_TAG_VIDEO ||
            tag_type == XM_TAG_AUDIO || tag_type == XM_TAG_HORIZONTAL_RULE) {
            result_.text += "\xEF\xBF\xBC"; // U+FFFC
            byte_offset_ += 3; // UTF-8 编码占 3 字节
        } else if (tag_type == XM_TAG_LINE_BREAK) {
            result_.text += "\n";
            byte_offset_ += 1;
        }

        // 段落级标签在子节点后追加换行（如果文本非空）
        if (tag_type == XM_TAG_PARAGRAPH && byte_offset_ > span_start) {
            result_.text += "\n";
            byte_offset_ += 1;
        }
```

- [ ] **步骤 5：运行测试验证通过**

运行：`cd build && cmake --build . && cd tests && ctest -V`

预期：所有测试通过，包括新增的占位字符测试和段落分隔测试

- [ ] **步骤 6：更新已有测试的断言**

检查 `tests/test_style_resolver.cpp:66`（`ImageTagWithSrc`）中的 `EXPECT_EQ(r.text, "")` —— image 现在会插入占位字符，需更新为：

```cpp
TEST_F(StyleResolverTest, ImageTagWithSrc) {
    auto r = resolve("<img src=\"photo.jpg\">");
    EXPECT_NE(r.text.find("\xEF\xBF\xBC"), std::string::npos); // 包含占位字符
    ASSERT_EQ(r.spans.size(), 1u);
    EXPECT_EQ(r.spans[0].tag, XM_TAG_IMAGE);
    EXPECT_EQ(r.spans[0].value, "photo.jpg");
    EXPECT_GT(r.spans[0].byte_end, r.spans[0].byte_start); // range 非零
}
```

同样检查 `tests/test_api.cpp:155`（`ImageWithSrc`）中是否需要更新断言。

- [ ] **步骤 7：Commit**

```bash
git add -A
git commit -m "feat: void/empty 元素插入占位字符，使 span range 非零长度

- image/video/audio/hr 插入 U+FFFC 对象替换字符
- br 插入 \\n 换行符
- p 标签在子节点后追加换行分隔
- 新增 ImageInsertsPlaceholder、LineBreakInsertsNewline 等测试
- 更新已有测试断言适配新行为"
```

---

### 任务 3：xmarkup_version() API

**文件：**
- 修改：`core/include/xmarkup/xmarkup.h`（添加声明）
- 修改：`core/src/api.cpp`（添加实现）
- 测试：`tests/test_api.cpp`

- [ ] **步骤 1：编写失败的测试**

在 `tests/test_api.cpp` 末尾添加：

```cpp
TEST_F(APITest, VersionString) {
    const char* ver = xmarkup_version();
    ASSERT_NE(ver, nullptr);
    EXPECT_STREQ(ver, "0.1.0");
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`cd build && cmake --build .`

预期：编译失败，`xmarkup_version` 未声明

- [ ] **步骤 3：在 xmarkup.h 添加声明**

在 `core/include/xmarkup/xmarkup.h` 的 `#ifdef __cplusplus` 之前、`XMParser` 声明之后添加：

```cpp
/* 版本查询 */
const char* xmarkup_version(void);
```

- [ ] **步骤 4：在 api.cpp 添加实现**

在 `core/src/api.cpp` 的 `extern "C"` 块内添加：

```cpp
const char* xmarkup_version(void) {
    return "0.1.0";
}
```

- [ ] **步骤 5：运行全部测试验证通过**

运行：`cd build && cmake --build . && cd tests && ctest -V`

预期：所有测试通过

- [ ] **步骤 6：Commit**

```bash
git add -A
git commit -m "feat: 添加 xmarkup_version() API 返回版本字符串"
```

---

### 任务 4：命名常量 + Doxygen 注释（所有核心文件）

**文件：** 所有 `core/src/*.h`、`core/src/*.cpp`、`core/include/xmarkup/xmarkup.h`

此任务为机械性改动，不改变任何运行时行为，不需要 TDD。

- [ ] **步骤 1：提取命名常量**

在 `core/src/style_resolver.cpp` 顶部（namespace xmarkup 之后）添加：

```cpp
// pt → px 换算系数：1pt = 1/72 inch, 96 dpi → 96/72 ≈ 1.333
static constexpr float kPtToPxFactor = 1.333f;

// 浏览器默认 heading 字号比例（相对 base font size）
// 来源：Chrome/Safari/Firefox 默认样式表
static constexpr float kHeadingScale[] = {
    2.0f,   // h1
    1.5f,   // h2
    1.17f,  // h3
    1.0f,   // h4
    0.83f,  // h5
    0.67f   // h6
};
```

将 `normalize_font_size()` 中的 `1.333` 替换为 `kPtToPxFactor`。

在 `core/src/tree_builder.cpp` 顶部添加：

```cpp
// HTML5 规范定义的 void 元素，不能有子节点
// https://html.spec.whatwg.org/multipage/syntax.html#void-elements
static const std::string_view kVoidElements[] = {
    "area", "base", "br", "col", "embed", "hr", "img", "input",
    "link", "meta", "param", "source", "track", "wbr"
};
```

将 `is_void_element()` 中的内联数组替换为 `kVoidElements`。

在 `core/src/api.cpp` 顶部添加：

```cpp
// 默认解析器配置
static constexpr uint8_t  kDefaultAutocorrect = 1;
static constexpr uint16_t kDefaultMaxNestingDepth = 256;
static constexpr float    kDefaultBaseFontSize = 16.0f;
```

将 `{1, 256, 16.0f}` 替换为使用这些常量。

在 `core/src/parser.h` 中将 `uint16_t max_depth` 改为 `uint16_t max_depth = kDefaultMaxNestingDepth`（或保持 inline）。

- [ ] **步骤 2：为所有头文件添加 Doxygen 注释**

**`core/include/xmarkup/xmarkup.h`** — 为所有公共类型和函数添加 Doxygen `/** */` 注释，包括 `@brief`、`@param`、`@return`、`@note`、`@code/@endcode` 使用示例。

示例（`xmarkup_create`）：
```cpp
/**
 * @brief 创建 XMarkup 解析器实例
 *
 * @param config 配置参数，传 NULL 使用默认值。调用者不需要释放 config。
 * @return 解析器指针，内存不足时返回 NULL
 * @note 返回的指针必须通过 xmarkup_destroy() 释放
 *
 * @code
 * XMParser* parser = xmarkup_create(NULL);
 * XMResult* result = xmarkup_parse(parser, "<b>Hello</b>", 13);
 * xmarkup_result_free(result);
 * xmarkup_destroy(parser);
 * @endcode
 *
 * @see xmarkup_destroy, XMConfig
 */
XMParser* xmarkup_create(const XMConfig* config);
```

为所有 6 个公共函数、5 个枚举、4 个结构体添加完整 Doxygen 注释。每个枚举值添加行尾注释。

**`core/src/tokenizer.h`** — 为 `Tokenizer` 类和所有方法添加 `/** */` 注释。

**`core/src/tree_builder.h`** — 为 `ASTNode`、`TreeBuilder` 类和所有方法添加注释。

**`core/src/style_resolver.h`** — 为 `InternalSpan`、`FlattenResult`、`StyleResolver` 类和所有方法添加注释。

**`core/src/entity_decoder.h`** — 为 `EntityDecoder` 类和所有方法添加注释。

**`core/src/utf16_indexer.h`** — 为 `ByteToUTF16`、`UTF16Indexer` 类和所有方法添加注释。

**`core/src/parser.h`** — 为 `ParserInternal` 结构体添加注释。

- [ ] **步骤 3：为实现文件添加逻辑注释**

为所有 `*.cpp` 文件的关键逻辑添加 `//` 行内注释：
- `tokenizer.cpp`：每个 state case 的状态转换逻辑
- `tree_builder.cpp`：栈操作的策略说明
- `style_resolver.cpp`：DFS 遍历策略、span 顺序保证、空白折叠规则
- `entity_decoder.cpp`：解码策略（分号匹配 vs 容错匹配）
- `utf16_indexer.cpp`：UTF-8 序列长度判定逻辑

在 `core/src/entity_decoder.cpp` 的 `named_entities()` 上方添加来源注释：
```cpp
// HTML5 命名实体映射表
// 来源：https://html.spec.whatwg.org/multipage/named-characters.html
```

在 `core/src/style_resolver.cpp` 的 `tag_map()` 上方添加策略注释：
```cpp
// HTML 标签 → XMTagType 映射策略：
// - 语义等价标签映射到同一类型（如 <b> 和 <strong> → XM_TAG_BOLD）
// - <source> 映射为 0（特殊处理，依赖父标签上下文判定 VIDEO_SOURCE/AUDIO_SOURCE）
```

- [ ] **步骤 4：运行全部测试验证无回归**

运行：`cd build && cmake --build . && cd tests && ctest -V`

预期：所有测试通过（仅注释和常量提取，无行为变更）

- [ ] **步骤 5：Commit**

```bash
git add -A
git commit -m "refactor: 提取命名常量 + 全文件 Doxygen 注释 + 逻辑注释

- 提取 kPtToPxFactor、kHeadingScale、kVoidElements 等命名常量
- 公共 API 头文件 100% Doxygen 注释覆盖
- 核心函数声明添加 Doxygen 注释
- 实现文件添加逻辑注释（解释 WHY）
- 硬编码值注明来源（HTML5 规范、浏览器默认样式表）"
```

---

### 任务 5：补充边界/异常测试用例

**文件：**
- 修改：`tests/test_style_resolver.cpp`
- 修改：`tests/test_entity_decoder.cpp`
- 修改：`tests/test_tokenizer.cpp`
- 修改：`tests/test_tree_builder.cpp`
- 修改：`tests/test_api.cpp`

- [ ] **步骤 1：在 test_style_resolver.cpp 添加边界用例**

```cpp
TEST_F(StyleResolverTest, CSSNegativeFontSize) {
    auto r = resolve(R"(<span style="font-size:-10px">text</span>)");
    // 负值字号：应忽略或输出原值
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
    // 空 style 不应产生 style span
}

TEST_F(StyleResolverTest, CSSInvalidColorValue) {
    auto r = resolve(R"(<span style="color:notacolor">text</span>)");
    EXPECT_EQ(r.text, "text");
    // 无效颜色值不应崩溃
}
```

- [ ] **步骤 2：在 test_entity_decoder.cpp 添加边界用例**

```cpp
TEST(EntityDecoder, OversizedNumericEntity) {
    // 超大数字实体应返回空（超出 Unicode 范围）
    EXPECT_EQ(EntityDecoder::decode("&#999999999;"), "&#999999999;");
}

TEST(EntityDecoder, ZeroNumericEntity) {
    // 零值实体应返回空字符串（无效码点）
    EXPECT_EQ(EntityDecoder::decode("&#0;"), "&#0;");
}

TEST(EntityDecoder, SurrogateRangeEntity) {
    // surrogate 范围码点应返回原始文本
    EXPECT_EQ(EntityDecoder::decode("&#xD800;"), "&#xD800;");
}
```

- [ ] **步骤 3：在 test_tokenizer.cpp 添加边界用例**

```cpp
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
```

- [ ] **步骤 4：在 test_api.cpp 添加多语言和边界用例**

```cpp
TEST_F(APITest, PureChineseHTML) {
    auto* r = parse("<b>你好世界</b>");
    ASSERT_NE(r, nullptr);
    EXPECT_STREQ(r->text, "\xe4\xbd\xa0\xe5\xa5\xbd\xe4\xb8\x96\xe7\x95\x8c");
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

TEST_F(APITest, ConsecutiveParseIndependence) {
    auto* r1 = parse("<b>first</b>");
    ASSERT_NE(r1, nullptr);
    EXPECT_STREQ(r1->text, "first");

    auto* r2 = parse("<i>second</i>");
    ASSERT_NE(r2, nullptr);
    EXPECT_STREQ(r2->text, "second");

    // r1 的数据不应被 r2 影响
    EXPECT_STREQ(r1->text, "first");

    xmarkup_result_free(r1);
    xmarkup_result_free(r2);
}
```

- [ ] **步骤 5：运行全部测试验证通过**

运行：`cd build && cmake --build . && cd tests && ctest -V`

预期：所有测试通过

- [ ] **步骤 6：Commit**

```bash
git add -A
git commit -m "test: 补充边界/异常测试用例

- StyleResolver：负值字号、零值字号、空 style、无效颜色
- EntityDecoder：超大数字实体、零值实体、surrogate 范围
- Tokenizer：属性值含 < 和 &
- API：纯中文 HTML、多语言混合、连续 parse 独立性"
```

---

### 任务 6：阶段一验证与合并

- [ ] **步骤 1：ASAN + UBSan 全量验证**

运行：
```bash
cd /path/to/XMarkup
mkdir -p build-asan && cd build-asan
cmake .. -DCMAKE_CXX_FLAGS="-fsanitize=address,undefined -fno-omit-frame-pointer" -DCMAKE_BUILD_TYPE=Debug
cmake --build .
cd tests && ctest -V
```

预期：所有测试通过，无 ASAN/UBSan 报错

- [ ] **步骤 2：合并到 main**

```bash
git checkout main
git merge --no-ff feat/core-engine-improvements -m "Merge feat/core-engine-improvements: 核心引擎改进（float 精度、占位字符、注释规范、测试补充）"
```

---

## 阶段二：iOS 桥接层

分支：`feat/ios-bridge`（从 main 创建）

### 任务 7：SPM 脚手架 + CXMarkup target

**文件：**
- 创建：`Package.swift`

- [ ] **步骤 1：创建 Package.swift**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "XMarkup",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
    ],
    products: [
        .library(name: "XMarkup", targets: ["XMarkup"]),
    ],
    targets: [
        .target(
            name: "CXMarkup",
            path: "core",
            sources: ["src"],
            publicHeadersPath: "include",
            cxxSettings: [
                .unsafeFlags(["-std=c++17"]),
                .headerSearchPath("src"),
            ]
        ),
        .target(
            name: "XMarkup",
            dependencies: ["CXMarkup"],
            path: "platforms/ios/Sources/XMarkup"
        ),
        .testTarget(
            name: "XMarkupTests",
            dependencies: ["XMarkup"],
            path: "platforms/ios/Tests/XMarkupTests"
        ),
    ]
)
```

- [ ] **步骤 2：创建目录结构**

```bash
mkdir -p platforms/ios/Sources/XMarkup
mkdir -p platforms/ios/Tests/XMarkupTests
```

- [ ] **步骤 3：创建占位文件验证 SPM 编译**

创建 `platforms/ios/Sources/XMarkup/Placeholder.swift`：

```swift
// 占位文件，验证 SPM target 结构
```

运行：`swift build`

预期：CXMarkup target 编译成功（C++ 源码编译通过），XMarkup target 暂时为空但可通过

- [ ] **步骤 4：删除占位文件，Commit**

```bash
rm platforms/ios/Sources/XMarkup/Placeholder.swift
git add Package.swift
git commit -m "build: 添加 SPM Package.swift（CXMarkup + XMarkup 双 target）"
```

---

### 任务 8：Swift 类型体系

**文件：**
- 创建：`platforms/ios/Sources/XMarkup/XMarkupError.swift`
- 创建：`platforms/ios/Sources/XMarkup/XMarkupTag.swift`
- 创建：`platforms/ios/Sources/XMarkup/XMarkupStyle.swift`
- 创建：`platforms/ios/Sources/XMarkup/XMarkupSpan.swift`
- 创建：`platforms/ios/Sources/XMarkup/XMarkupResult.swift`
- 创建：`platforms/ios/Sources/XMarkup/PlatformTypes.swift`
- 测试：`platforms/ios/Tests/XMarkupTests/XMarkupResultTests.swift`

- [ ] **步骤 1：创建 PlatformTypes.swift**

```swift
/// 跨平台字体和颜色类型别名
///
/// iOS 上 XMFont = UIFont，XMColor = UIColor
/// macOS 上 XMFont = NSFont，XMColor = NSColor
#if canImport(UIKit)
import UIKit
public typealias XMFont = UIFont
public typealias XMColor = UIColor
#elseif canImport(AppKit)
import AppKit
public typealias XMFont = NSFont
public typealias XMColor = NSColor
#endif
```

- [ ] **步骤 2：创建 XMarkupError.swift**

```swift
/// XMarkup 解析错误
public enum XMarkupError: Error, Sendable {
    /// 解析器指针为 NULL
    case nullParser
    /// 输入 HTML 为 NULL
    case nullInput
    /// 嵌套深度超出限制，已截断
    case nestingOverflow
    /// 内存分配失败
    case allocationFailed
    /// 未知错误，保留原始错误码
    case unknown(code: Int32)

    /// 从 C API 错误码初始化
    init(cError: XMError) {
        switch cError {
        case XM_ERR_NULL_PARSER:      self = .nullParser
        case XM_ERR_NULL_INPUT:       self = .nullInput
        case XM_ERR_NESTING_OVERFLOW: self = .nestingOverflow
        case XM_ERR_ALLOC_FAILED:     self = .allocationFailed
        default:                      self = .unknown(code: Int32(truncatingIfNeeded: cError.rawValue))
        }
    }
}
```

- [ ] **步骤 3：创建 XMarkupTag.swift**

```swift
/// HTML 标签类型
///
/// 映射 HTML 标签到语义化的 Swift 枚举。
/// 对于未知标签，保留原始 C 值供调试。
public enum XMarkupTag: Sendable {
    // 文本样式
    case bold
    case italic
    case underline
    case strikethrough
    case subscriptText
    case superscript
    case mark
    case code
    // 段落结构
    case paragraph
    case heading1
    case heading2
    case heading3
    case heading4
    case heading5
    case heading6
    case blockquote
    case preformatted
    // 链接与媒体
    case link
    case image
    case video
    case videoSource
    case audio
    case audioSource
    // 列表
    case listOrdered
    case listUnordered
    case listItem
    // 表格
    case table
    case tableRow
    case tableCell
    case tableHeader
    // 其他
    case horizontalRule
    case lineBreak
    case division
    case span
    // 未知标签，保留原始 C 值
    case unknown(tagValue: UInt32)

    /// 从 C API XMTagType 值初始化
    init(cValue: XMTagType) {
        switch cValue {
        case XM_TAG_BOLD:          self = .bold
        case XM_TAG_ITALIC:        self = .italic
        case XM_TAG_UNDERLINE:     self = .underline
        case XM_TAG_STRIKETHROUGH: self = .strikethrough
        case XM_TAG_SUBSCRIPT:     self = .subscriptText
        case XM_TAG_SUPERSCRIPT:   self = .superscript
        case XM_TAG_MARK:          self = .mark
        case XM_TAG_CODE:          self = .code
        case XM_TAG_PARAGRAPH:     self = .paragraph
        case XM_TAG_HEADING_1:     self = .heading1
        case XM_TAG_HEADING_2:     self = .heading2
        case XM_TAG_HEADING_3:     self = .heading3
        case XM_TAG_HEADING_4:     self = .heading4
        case XM_TAG_HEADING_5:     self = .heading5
        case XM_TAG_HEADING_6:     self = .heading6
        case XM_TAG_BLOCKQUOTE:    self = .blockquote
        case XM_TAG_PREFORMATTED:  self = .preformatted
        case XM_TAG_LINK:          self = .link
        case XM_TAG_IMAGE:         self = .image
        case XM_TAG_VIDEO:         self = .video
        case XM_TAG_VIDEO_SOURCE:  self = .videoSource
        case XM_TAG_AUDIO:         self = .audio
        case XM_TAG_AUDIO_SOURCE:  self = .audioSource
        case XM_TAG_LIST_ORDERED:  self = .listOrdered
        case XM_TAG_LIST_UNORDERED:self = .listUnordered
        case XM_TAG_LIST_ITEM:     self = .listItem
        case XM_TAG_TABLE:         self = .table
        case XM_TAG_TABLE_ROW:     self = .tableRow
        case XM_TAG_TABLE_CELL:    self = .tableCell
        case XM_TAG_TABLE_HEADER:  self = .tableHeader
        case XM_TAG_HORIZONTAL_RULE: self = .horizontalRule
        case XM_TAG_LINE_BREAK:    self = .lineBreak
        case XM_TAG_DIVISION:      self = .division
        case XM_TAG_SPAN:          self = .span
        default:                   self = .unknown(tagValue: cValue.rawValue)
        }
    }
}
```

- [ ] **步骤 4：创建 XMarkupStyle.swift**

```swift
/// CSS 行内样式属性类型
public enum XMarkupStyle: Sendable {
    case foregroundColor
    case backgroundColor
    case fontSize
    case fontWeight
    case fontStyle
    case textDecoration
    case lineHeight
    case textAlign
    case letterSpacing
    case unknown(styleValue: UInt32)

    /// 从 C API XMStyleType 值初始化
    init(cValue: XMStyleType) {
        switch cValue {
        case XM_STYLE_FOREGROUND_COLOR: self = .foregroundColor
        case XM_STYLE_BACKGROUND_COLOR: self = .backgroundColor
        case XM_STYLE_FONT_SIZE:        self = .fontSize
        case XM_STYLE_FONT_WEIGHT:      self = .fontWeight
        case XM_STYLE_FONT_STYLE:       self = .fontStyle
        case XM_STYLE_TEXT_DECORATION:  self = .textDecoration
        case XM_STYLE_LINE_HEIGHT:      self = .lineHeight
        case XM_STYLE_TEXT_ALIGN:       self = .textAlign
        case XM_STYLE_LETTER_SPACING:   self = .letterSpacing
        default:                        self = .unknown(styleValue: cValue.rawValue)
        }
    }
}
```

- [ ] **步骤 5：创建 XMarkupSpan.swift**

```swift
/// 样式区间，描述一个标签或 CSS 属性在文本中的位置
///
/// `range` 使用 UTF-16 码元索引，与 NSString/NSAttributedString 索引体系直接对齐。
public struct XMarkupSpan: Sendable {
    /// 文本区间（UTF-16 码元索引，半开区间 [start, end)）
    public let range: NSRange
    /// 标签类型
    public let tag: XMarkupTag
    /// CSS 样式类型
    public let style: XMarkupStyle
    /// 属性值（href/src/颜色值等），可能为 nil
    public let value: String?
}
```

- [ ] **步骤 6：创建 XMarkupResult.swift**

```swift
import CXMarkup

/// XMarkup 解析结果
///
/// 值类型，不可变，`Sendable` 安全。
/// 包含原始解析数据（text + spans）和便利转换方法。
///
/// 使用方式：
/// ```swift
/// let result = try parser.parse("<b>Hello</b>")
/// print(result.text)       // "Hello"
/// print(result.spans)      // [XMarkupSpan(tag: .bold, range: (0,5))]
/// let attributed = result.makeAttributedString()
/// ```
public struct XMarkupResult: Sendable {
    /// 纯文本（HTML 标签已移除，实体已解码）
    public let text: String
    /// 样式区间数组
    public let spans: [XMarkupSpan]

    /// 从 C API XMResult 指针转换
    static func fromC(_ cResult: UnsafeMutablePointer<XMResult>) -> XMarkupResult {
        let text: String
        if let t = cResult.pointee.text {
            text = String(cString: t)
        } else {
            text = ""
        }

        let count = Int(cResult.pointee.span_count)
        var spans: [XMarkupSpan] = []
        spans.reserveCapacity(count)

        if let cSpans = cResult.pointee.spans {
            for i in 0..<count {
                let s = cSpans[i]
                let value: String? = s.value != nil ? String(cString: s.value!) : nil
                spans.append(XMarkupSpan(
                    range: NSRange(location: Int(s.range.start), length: Int(s.range.end - s.range.start)),
                    tag: XMarkupTag(cValue: s.tag),
                    style: XMarkupStyle(cValue: s.style),
                    value: value
                ))
            }
        }

        return XMarkupResult(text: text, spans: spans)
    }

    /// 转换为 NSAttributedString（便利层，在任务 10 中实现）
    public func makeAttributedString(baseFont: XMFont? = nil) -> NSAttributedString {
        // 占位实现，后续任务补充
        return NSAttributedString(string: text)
    }
}
```

- [ ] **步骤 7：编写类型转换测试**

创建 `platforms/ios/Tests/XMarkupTests/XMarkupResultTests.swift`：

```swift
import XCTest
@testable import XMarkup
import CXMarkup

final class XMarkupResultTests: XCTestCase {

    func testTagMapping() {
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_BOLD), .bold)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_ITALIC), .italic)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_LINK), .link)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_HEADING_1), .heading1)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_LINE_BREAK), .lineBreak)
    }

    func testUnknownTag() {
        if case .unknown(let val) = XMarkupTag(cValue: XMTagType(rawValue: 999)) {
            XCTAssertEqual(val, 999)
        } else {
            XCTFail("Expected unknown tag")
        }
    }

    func testStyleMapping() {
        XCTAssertEqual(XMarkupStyle(cValue: XM_STYLE_FOREGROUND_COLOR), .foregroundColor)
        XCTAssertEqual(XMarkupStyle(cValue: XM_STYLE_FONT_SIZE), .fontSize)
    }

    func testErrorMapping() {
        XCTAssertEqual(XMarkupError(cError: XM_ERR_NULL_PARSER), .nullParser)
        XCTAssertEqual(XMarkupError(cError: XM_ERR_NULL_INPUT), .nullInput)
        XCTAssertEqual(XMarkupError(cError: XM_OK), .unknown(code: 0))
    }
}
```

- [ ] **步骤 8：运行测试验证通过**

运行：`swift build && swift test`

预期：编译通过，`XMarkupResultTests` 全部通过

- [ ] **步骤 9：Commit**

```bash
git add -A
git commit -m "feat(ios): 添加 Swift 类型体系

- XMarkupError：错误枚举 + init(cError:) 映射
- XMarkupTag：标签枚举（无 rawValue）+ init(cValue:) 映射
- XMarkupStyle：CSS 样式枚举 + init(cValue:) 映射
- XMarkupSpan：样式区间结构体（NSRange）
- XMarkupResult：解析结果 + fromC() 转换
- PlatformTypes：跨平台 XMFont/XMColor typealias"
```

---

### 任务 9：XMarkupParser 封装

**文件：**
- 创建：`platforms/ios/Sources/XMarkup/XMarkupParser.swift`
- 测试：`platforms/ios/Tests/XMarkupTests/XMarkupParserTests.swift`

- [ ] **步骤 1：编写失败的测试**

创建 `platforms/ios/Tests/XMarkupTests/XMarkupParserTests.swift`：

```swift
import XCTest
@testable import XMarkup

final class XMarkupParserTests: XCTestCase {

    func testCreateWithDefaultConfig() throws {
        let parser = try XMarkupParser()
        XCTAssertEqual(parser.baseFontSize, 16.0)
    }

    func testCreateWithCustomConfig() throws {
        let parser = try XMarkupParser(baseFontSize: 14.5, maxNestingDepth: 128, autocorrect: false)
        XCTAssertEqual(parser.baseFontSize, 14.5)
    }

    func testParseSimpleBold() throws {
        let parser = try XMarkupParser()
        let result = try parser.parse("<b>bold</b>")
        XCTAssertEqual(result.text, "bold")
        XCTAssertEqual(result.spans.count, 1)
        XCTAssertEqual(result.spans[0].tag, .bold)
        XCTAssertEqual(result.spans[0].range.location, 0)
        XCTAssertEqual(result.spans[0].range.length, 4)
    }

    func testParseEmptyInput() throws {
        let parser = try XMarkupParser()
        let result = try parser.parse("")
        XCTAssertEqual(result.text, "")
        XCTAssertEqual(result.spans.count, 0)
    }

    func testParsePureText() throws {
        let parser = try XMarkupParser()
        let result = try parser.parse("Hello World")
        XCTAssertEqual(result.text, "Hello World")
        XCTAssertEqual(result.spans.count, 0)
    }

    func testParseNestedBoldItalic() throws {
        let parser = try XMarkupParser()
        let result = try parser.parse("<b><i>text</i></b>")
        XCTAssertEqual(result.text, "text")
        XCTAssertEqual(result.spans.count, 2)
        XCTAssertEqual(result.spans[0].tag, .bold)
        XCTAssertEqual(result.spans[1].tag, .italic)
    }

    func testParseLinkWithHref() throws {
        let parser = try XMarkupParser()
        let result = try parser.parse("<a href=\"https://example.com\">click</a>")
        XCTAssertEqual(result.text, "click")
        XCTAssertEqual(result.spans[0].tag, .link)
        XCTAssertEqual(result.spans[0].value, "https://example.com")
    }

    func testConsecutiveParseIndependence() throws {
        let parser = try XMarkupParser()
        let r1 = try parser.parse("<b>first</b>")
        let r2 = try parser.parse("<i>second</i>")
        XCTAssertEqual(r1.text, "first")
        XCTAssertEqual(r2.text, "second")
        XCTAssertEqual(r1.spans[0].tag, .bold)
        XCTAssertEqual(r2.spans[0].tag, .italic)
    }

    func testDeinitReleasesResource() throws {
        // 确保 deinit 不崩溃
        autoreleasepool {
            let parser = try XMarkupParser()
            _ = try parser.parse("<b>test</b>")
            // parser 离开作用域后 deinit 自动调用 xmarkup_destroy
        }
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`swift build`

预期：编译失败，`XMarkupParser` 类型未定义

- [ ] **步骤 3：创建 XMarkupParser.swift**

```swift
import CXMarkup

/// XMarkup HTML 解析器
///
/// 将 HTML 转换为纯文本 + 样式区间，供桥接层消费。
///
/// 使用方式：
/// ```swift
/// let parser = try XMarkupParser(baseFontSize: 14.5)
/// let result = try parser.parse("<b>Hello</b> <i>World</i>")
/// let attributed = result.makeAttributedString()
/// ```
///
/// - Note: 线程安全保证与 C 核心引擎一致：不同实例可跨线程并发使用，
///         同一实例不可并发调用。
public final class XMarkupParser: @unchecked Sendable {

    // MARK: - Public Properties

    /// 当前配置的基准字号（保留 CGFloat 精度，用于 UIFont 渲染）
    public let baseFontSize: CGFloat

    // MARK: - Private Properties

    private let handle: OpaquePointer

    // MARK: - Initialization

    /// 创建解析器
    ///
    /// - Parameters:
    ///   - baseFontSize: 基准字号（pt），用于 CSS em/rem/% 单位换算，默认 16
    ///   - maxNestingDepth: 最大嵌套深度，超出截断，默认 256
    ///   - autocorrect: 是否自动纠错乱序嵌套/未闭合标签，默认 true
    /// - Throws: 内存不足时抛出 `XMarkupError.allocationFailed`
    public init(
        baseFontSize: CGFloat = 16,
        maxNestingDepth: UInt16 = 256,
        autocorrect: Bool = true
    ) throws {
        self.baseFontSize = baseFontSize
        var config = XMConfig()
        config.enable_autocorrect = autocorrect ? 1 : 0
        config.max_nesting_depth = maxNestingDepth
        config.base_font_size = Float(baseFontSize)
        guard let ptr = xmarkup_create(&config) else {
            throw XMarkupError.allocationFailed
        }
        handle = ptr
    }

    deinit {
        xmarkup_destroy(handle)
    }

    // MARK: - Public Methods

    /// 解析 HTML 字符串
    ///
    /// - Parameter html: HTML 输入（UTF-8 编码）
    /// - Returns: 解析结果，包含纯文本和样式区间
    /// - Throws: `XMarkupError` 各种解析错误
    public func parse(_ html: String) throws -> XMarkupResult {
        let cResult = html.withCString { ptr in
            xmarkup_parse(handle, ptr, html.utf8.count)
        }

        guard let cResult else {
            let error = xmarkup_last_error(handle)
            throw XMarkupError(cError: error)
        }
        defer { xmarkup_result_free(cResult) }

        let err = cResult.pointee.error
        guard err == XM_OK else {
            throw XMarkupError(cError: err)
        }

        return XMarkupResult.fromC(cResult)
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：`swift build && swift test --filter XMarkupParserTests`

预期：所有 8 个 parser 测试通过

- [ ] **步骤 5：Commit**

```bash
git add -A
git commit -m "feat(ios): 添加 XMarkupParser 封装

- final class + @unchecked Sendable
- RAII 生命周期（init 创建 / deinit 销毁）
- parse() 内部 defer result_free，无悬垂指针
- 8 个测试用例覆盖：默认/自定义配置、空输入、嵌套、链接、连续 parse、deinit"
```

---

### 任务 10：ColorParser

**文件：**
- 创建：`platforms/ios/Sources/XMarkup/ColorParser.swift`
- 测试：`platforms/ios/Tests/XMarkupTests/ColorParserTests.swift`

- [ ] **步骤 1：编写失败的测试**

创建 `platforms/ios/Tests/XMarkupTests/ColorParserTests.swift`：

```swift
import XCTest
@testable import XMarkup

final class ColorParserTests: XCTestCase {

    func testRed() {
        let color = ColorParser.parse("#FF0000")
        XCTAssertNotNil(color)
    }

    func testGreen() {
        let color = ColorParser.parse("#00FF00")
        XCTAssertNotNil(color)
    }

    func testBlue() {
        let color = ColorParser.parse("#0000FF")
        XCTAssertNotNil(color)
    }

    func testBlack() {
        let color = ColorParser.parse("#000000")
        XCTAssertNotNil(color)
    }

    func testLowercase() {
        let color = ColorParser.parse("#ff0000")
        XCTAssertNotNil(color)
    }

    func testNilInput() {
        let color = ColorParser.parse(nil)
        XCTAssertNil(color)
    }

    func testEmptyInput() {
        let color = ColorParser.parse("")
        XCTAssertNil(color)
    }

    func testInvalidFormat() {
        let color = ColorParser.parse("not-a-color")
        XCTAssertNil(color)
    }

    func testShortHex() {
        // #RGB 短格式不被 C 引擎输出，但容错处理
        let color = ColorParser.parse("#F00")
        XCTAssertNil(color)
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`swift build`

预期：编译失败，`ColorParser` 类型未定义

- [ ] **步骤 3：创建 ColorParser.swift**

```swift
/// 十六进制颜色解析工具
///
/// 将 C 引擎输出的 `#RRGGBB` 格式字符串解析为 `XMColor`。
enum ColorParser {

    /// 解析 #RRGGBB 格式的颜色字符串
    ///
    /// - Parameter hex: 颜色字符串，格式 "#RRGGBB"
    /// - Returns: XMColor，无效格式返回 nil
    static func parse(_ hex: String?) -> XMColor? {
        guard let hex, hex.count == 7, hex.first == "#" else { return nil }

        let start = hex.index(hex.startIndex, offsetBy: 1)
        let hexColor = String(hex[start...])

        guard let rgb = UInt64(hexColor, radix: 16) else { return nil }

        let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let g = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let b = CGFloat(rgb & 0xFF) / 255.0

        #if canImport(UIKit)
        return XMColor(red: r, green: g, blue: b, alpha: 1.0)
        #elseif canImport(AppKit)
        return XMColor(red: r, green: g, blue: b, alpha: 1.0)
        #endif
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：`swift build && swift test --filter ColorParserTests`

预期：全部 9 个测试通过

- [ ] **步骤 5：Commit**

```bash
git add -A
git commit -m "feat(ios): 添加 ColorParser #RRGGBB 颜色解析

- 支持 7 位 #RRGGBB 格式解析为 XMColor
- 跨平台兼容（UIColor/NSColor）
- 9 个测试覆盖：有效颜色、大小写、nil/空/无效输入"
```

---

### 任务 11：NSAttributedString 便利层

**文件：**
- 创建：`platforms/ios/Sources/XMarkup/NSAttributedString+XMarkup.swift`
- 修改：`platforms/ios/Sources/XMarkup/XMarkupResult.swift`（更新 `makeAttributedString`）
- 测试：`platforms/ios/Tests/XMarkupTests/NSAttributedStringTests.swift`

- [ ] **步骤 1：编写失败的测试**

创建 `platforms/ios/Tests/XMarkupTests/NSAttributedStringTests.swift`：

```swift
import XCTest
@testable import XMarkup

final class NSAttributedStringTests: XCTestCase {

    private func parse(_ html: String) throws -> XMarkupResult {
        let parser = try XMarkupParser()
        return try parser.parse(html)
    }

    func testBoldFontTrait() throws {
        let result = try parse("<b>bold</b>")
        let attr = result.makeAttributedString()
        let font = attr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertNotNil(font)
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.traitBold))
    }

    func testItalicFontTrait() throws {
        let result = try parse("<i>italic</i>")
        let attr = result.makeAttributedString()
        let font = attr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertNotNil(font)
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.traitItalic))
    }

    func testBoldItalicMerged() throws {
        let result = try parse("<b><i>both</i></b>")
        let attr = result.makeAttributedString()
        let font = attr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertNotNil(font)
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.traitBold))
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.traitItalic))
    }

    func testUnderlineStyle() throws {
        let result = try parse("<u>under</u>")
        let attr = result.makeAttributedString()
        let style = attr.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int
        XCTAssertEqual(style, NSUnderlineStyle.single.rawValue)
    }

    func testStrikethroughStyle() throws {
        let result = try parse("<s>strike</s>")
        let attr = result.makeAttributedString()
        let style = attr.attribute(.strikethroughStyle, at: 0, effectiveRange: nil) as? Int
        XCTAssertEqual(style, NSUnderlineStyle.single.rawValue)
    }

    func testLinkAttribute() throws {
        let result = try parse("<a href=\"https://example.com\">click</a>")
        let attr = result.makeAttributedString()
        let link = attr.attribute(.link, at: 0, effectiveRange: nil) as? String
        XCTAssertEqual(link, "https://example.com")
    }

    func testCSSForegroundColor() throws {
        let result = try parse("<span style=\"color:#FF0000\">red</span>")
        let attr = result.makeAttributedString()
        let color = attr.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? XMColor
        XCTAssertNotNil(color)
    }

    func testCSSBackgroundColor() throws {
        let result = try parse("<span style=\"background-color:#0000FF\">bg</span>")
        let attr = result.makeAttributedString()
        let color = attr.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? XMColor
        XCTAssertNotNil(color)
    }

    func testCustomBaseFont() throws {
        let result = try parse("<b>text</b>")
        #if canImport(UIKit)
        let customFont = UIFont.systemFont(ofSize: 20)
        #elseif canImport(AppKit)
        let customFont = NSFont.systemFont(ofSize: 20)
        #endif
        let attr = result.makeAttributedString(baseFont: customFont)
        let font = attr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertEqual(font?.pointSize, 20)
    }

    func testUnknownTagNoCrash() throws {
        let result = try parse("<custom>text</custom>")
        let attr = result.makeAttributedString()
        XCTAssertEqual(attr.string, "text")
    }

    func testEmptyInputReturnsEmpty() throws {
        let result = try parse("")
        let attr = result.makeAttributedString()
        XCTAssertEqual(attr.string, "")
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`swift build`

预期：编译通过但部分测试失败（`makeAttributedString` 当前返回纯文本无属性）

- [ ] **步骤 3：创建 NSAttributedString+XMarkup.swift**

```swift
import Foundation

/// NSAttributedString 便利层：span→attribute 映射
extension XMarkupResult {

    /// 将解析结果转换为 NSAttributedString
    ///
    /// 使用方式：
    /// ```swift
    /// let result = try parser.parse("<b>Hello</b> <i style=\"color:#FF0000\">World</i>")
    /// let attributed = result.makeAttributedString(baseFont: UIFont.systemFont(ofSize: 14))
    /// // attributed 可直接用于 UILabel.attributedText / NSTextField.attributedStringValue
    /// ```
    ///
    /// - Parameter baseFont: 基础字体，nil 时使用 systemFont(ofSize: 16)
    /// - Returns: 带样式的 NSAttributedString
    public func makeAttributedString(baseFont: XMFont? = nil) -> NSAttributedString {
        let base = baseFont ?? XMFont.systemFont(ofSize: 16)

        guard !text.isEmpty else {
            return NSAttributedString(string: "")
        }

        let str = NSMutableAttributedString(string: text, attributes: [.font: base])

        // 第一趟：合并字体属性
        for span in spans {
            applyFontAttributes(span, baseFontSize: base.pointSize, to: str)
        }

        // 第二趟：非字体属性
        for span in spans {
            applyNonFontAttributes(span, to: str)
        }

        return NSAttributedString(attributedString: str)
    }

    // MARK: - Private

    /// 第一趟：处理字体相关属性（合并 trait 而非覆盖）
    private func applyFontAttributes(_ span: XMarkupSpan, baseFontSize: CGFloat,
                                     to string: NSMutableAttributedString) {
        let range = span.range

        switch span.tag {
        case .bold:
            addFontTrait(.traitBold, to: range, in: string)
        case .italic:
            addFontTrait(.traitItalic, to: range, in: string)
        case .heading1:
            applyHeadingFont(scale: 2.0, to: range, in: string)
        case .heading2:
            applyHeadingFont(scale: 1.5, to: range, in: string)
        case .heading3:
            applyHeadingFont(scale: 1.17, to: range, in: string)
        case .heading4:
            applyHeadingFont(scale: 1.0, to: range, in: string)
        case .heading5:
            applyHeadingFont(scale: 0.83, to: range, in: string)
        case .heading6:
            applyHeadingFont(scale: 0.67, to: range, in: string)
        case .code:
            applyCodeFont(to: range, in: string)
        default:
            break
        }

        // CSS fontSize
        if span.style == .fontSize, let value = span.value, let size = Float(value) {
            applyFontSize(CGFloat(size), to: range, in: string)
        }
    }

    /// 第二趟：处理非字体属性
    private func applyNonFontAttributes(_ span: XMarkupSpan, to string: NSMutableAttributedString) {
        let range = span.range

        switch span.tag {
        case .underline:
            string.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        case .strikethrough:
            string.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        case .link:
            if let url = span.value {
                string.addAttribute(.link, value: url, range: range)
            }
        default:
            break
        }

        switch span.style {
        case .foregroundColor:
            if let color = ColorParser.parse(span.value) {
                string.addAttribute(.foregroundColor, value: color, range: range)
            }
        case .backgroundColor:
            if let color = ColorParser.parse(span.value) {
                string.addAttribute(.backgroundColor, value: color, range: range)
            }
        default:
            break
        }
    }

    /// 向指定范围追加字体 trait（合并而非覆盖）
    ///
    /// 处理 <b><i>text</i></b> 场景：先应用 BOLD trait，
    /// 再在同一范围应用 ITALIC trait，最终得到 Bold-Italic 字体。
    private func addFontTrait(_ trait: XMFontDescriptor.SymbolicTraits,
                              to range: NSRange,
                              in string: NSMutableAttributedString) {
        string.enumerateAttribute(.font, in: range) { currentFont, attrRange, _ in
            guard let font = currentFont as? XMFont else { return }
            var traits = font.fontDescriptor.symbolicTraits
            traits.insert(trait)
            if let descriptor = font.fontDescriptor.withSymbolicTraits(traits),
               let newFont = XMFont(descriptor: descriptor, size: font.pointSize) {
                string.addAttribute(.font, value: newFont, range: attrRange)
            }
        }
    }

    /// 应用 heading 字体（放大 + 加粗）
    private func applyHeadingFont(scale: CGFloat, to range: NSRange,
                                  in string: NSMutableAttributedString) {
        string.enumerateAttribute(.font, in: range) { currentFont, attrRange, _ in
            guard let font = currentFont as? XMFont else { return }
            let newSize = font.pointSize * scale
            let descriptor = font.fontDescriptor.withSymbolicTraits(.traitBold)
            if let desc = descriptor,
               let newFont = XMFont(descriptor: desc, size: newSize) {
                string.addAttribute(.font, value: newFont, range: attrRange)
            }
        }
    }

    /// 应用等宽字体（用于 <code>）
    private func applyCodeFont(to range: NSRange, in string: NSMutableAttributedString) {
        string.enumerateAttribute(.font, in: range) { currentFont, attrRange, _ in
            guard let font = currentFont as? XMFont else { return }
            #if canImport(UIKit)
            let monoFont = UIFont(name: "Menlo", size: font.pointSize) ?? UIFont.monospacedSystemFont(ofSize: font.pointSize, weight: .regular)
            #elseif canImport(AppKit)
            let monoFont = NSFont(name: "Menlo", size: font.pointSize) ?? NSFont.monospacedSystemFont(ofSize: font.pointSize, weight: .regular)
            #endif
            string.addAttribute(.font, value: monoFont, range: attrRange)
        }
    }

    /// 应用 CSS 指定字号
    private func applyFontSize(_ size: CGFloat, to range: NSRange,
                               in string: NSMutableAttributedString) {
        string.enumerateAttribute(.font, in: range) { currentFont, attrRange, _ in
            guard let font = currentFont as? XMFont else { return }
            let descriptor = font.fontDescriptor
            if let newFont = XMFont(descriptor: descriptor, size: size) {
                string.addAttribute(.font, value: newFont, range: attrRange)
            }
        }
    }
}
```

- [ ] **步骤 4：更新 XMarkupResult.swift 中的 makeAttributedString**

移除 `XMarkupResult.swift` 中的占位 `makeAttributedString` 方法（因为已移到 extension 中）。将方法声明改为空（由 extension 提供）。

- [ ] **步骤 5：运行测试验证通过**

运行：`swift build && swift test --filter NSAttributedStringTests`

预期：全部 11 个测试通过

- [ ] **步骤 6：运行全部测试**

运行：`swift test`

预期：所有 Swift 测试通过（Parser + Result + ColorParser + NSAttributedString）

- [ ] **步骤 7：Commit**

```bash
git add -A
git commit -m "feat(ios): 添加 NSAttributedString 便利层

- 两趟处理算法：先合并字体属性，再添加非字体属性
- BOLD/ITALIC trait 合并而非覆盖
- Heading 字号比例（h1 2.0× ~ h6 0.67×）
- CSS foregroundColor/backgroundColor 映射
- underline/strikethrough/link 属性映射
- 11 个测试覆盖：字体合并、颜色、链接、自定义字体、边界情况"
```

---

### 任务 12：SwiftLint + SwiftFormat 配置 + 跨平台验证

**文件：**
- 创建：`.swiftlint.yml`
- 创建：`.swiftformat`
- 创建：`platforms/ios/Tests/XMarkupTests/CrossPlatformTests.swift`

- [ ] **步骤 1：创建 .swiftlint.yml**

```yaml
included:
  - platforms/ios/Sources/XMarkup
  - platforms/ios/Tests/XMarkupTests

opt_in_rules:
  - empty_count
  - closure_spacing
  - force_unwrapping
  - implicitly_unwrapped_optional
  - overridden_super_call
  - private_outlet
  - vertical_whitespace_closing_braces

disabled_rules:
  - trailing_whitespace

type_name:
  min_length: 3
  max_length: 50

identifier_name:
  min_length: 2
  allowed_symbols: ["_"]

line_length:
  warning: 120
  error: 200

function_body_length:
  warning: 50
  error: 100

file_length:
  warning: 500
  error: 1000
```

- [ ] **步骤 2：创建 .swiftformat**

```
# SwiftFormat 配置
--swiftversion 6.0
--indent 4
--tabwidth 4
--smarttabs enabled
--self remove
--trimwhitespace always
--voidtype void
--commas always
--decimalgrouping 3,6
--exponentcase lowercase
--header ignore
--ifdef indent
--importgrouping alpha
--indentcase false
--ranges spaced
--semicolons never
--stripunusedargs closure-only
--trimwhitespace always
--wraparguments before-first
--wrapcollections before-first
```

- [ ] **步骤 3：创建跨平台验证测试**

创建 `platforms/ios/Tests/XMarkupTests/CrossPlatformTests.swift`：

```swift
import XCTest
@testable import XMarkup

/// 验证跨平台类型别名和基础功能在当前平台上正确工作
final class CrossPlatformTests: XCTestCase {

    func testXMFontTypeExists() {
        #if canImport(UIKit)
        let font = XMFont.systemFont(ofSize: 16)
        XCTAssertEqual(font.pointSize, 16)
        #elseif canImport(AppKit)
        let font = XMFont.systemFont(ofSize: 16)
        XCTAssertEqual(font.pointSize, 16)
        #endif
    }

    func testXMColorTypeExists() {
        #if canImport(UIKit)
        let color = XMColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        XCTAssertNotNil(color)
        #elseif canImport(AppKit)
        let color = XMColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        XCTAssertNotNil(color)
        #endif
    }

    func testColorParserReturnsXMColor() {
        let color = ColorParser.parse("#FF0000")
        XCTAssertNotNil(color)
    }
}
```

- [ ] **步骤 4：运行全部测试（最终验证）**

运行：`swift build && swift test`

预期：所有测试通过

- [ ] **步骤 5：Commit**

```bash
git add -A
git commit -m "build(ios): 添加 SwiftLint/SwiftFormat 配置 + 跨平台验证

- .swiftlint.yml：启用 opt_in 规则，配置行长度限制
- .swiftformat：Swift 6.0 格式化规则
- CrossPlatformTests：验证 XMFont/XMColor 类型别名正确"
```

---

### 任务 13：阶段二验证与合并

- [ ] **步骤 1：C++ 核心引擎回归测试**

运行：
```bash
cd build && cmake --build . && cd tests && ctest -V
```

预期：所有 C++ 测试通过

- [ ] **步骤 2：Swift 全量测试**

运行：`swift test`

预期：所有 Swift 测试通过

- [ ] **步骤 3：合并到 main**

```bash
git checkout main
git merge --no-ff feat/ios-bridge -m "Merge feat/ios-bridge: iOS 桥接层完成（SPM + Swift 类型 + NSAttributedString 便利层）"
```

- [ ] **步骤 4：推送到远程**

```bash
git push origin main
```
