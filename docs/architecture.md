# XMarkup 架构文档

> 版本：0.1.0

本文档面向贡献者和维护者，描述 XMarkup 核心引擎的架构设计、模块职责、数据流和扩展指南。

---

## 目录

- [架构概览](#架构概览)
- [处理管线](#处理管线)
- [模块详解](#模块详解)
- [数据流图](#数据流图)
- [关键设计决策](#关键设计决策)
- [测试策略](#测试策略)
- [扩展指南](#扩展指南)
- [子项目 B 路线图](#子项目-b-路线图)

---

## 架构概览

XMarkup 采用**管线式架构**（Pipeline Architecture），HTML 输入经过 5 个串行处理阶段，最终输出纯文本 + UTF-16 索引样式区间。

```
┌──────────────────────────────────────────────────────────────┐
│                        extern "C" API                        │
│  xmarkup_create → xmarkup_parse → XMResult → xmarkup_free   │
└──────────────────────────┬───────────────────────────────────┘
                           │
                    ┌──────▼──────┐
                    │    Parser    │  管线编排
                    └──────┬──────┘
                           │
    ┌──────────┬───────────┼───────────┬──────────┐
    ▼          ▼           ▼           ▼          ▼
┌───────┐ ┌──────────┐ ┌──────────┐ ┌────────┐ ┌─────────┐
│Tokenizer│ │TreeBuilder│ │EntityDecoder│ │Style   │ │UTF16    │
│词法分析 │ │AST 构建   │ │实体解码    │ │Resolver│ │Indexer  │
└───────┘ └──────────┘ └──────────┘ └────────┘ └─────────┘
```

**设计原则：**

- **单向数据流**：每个模块只依赖前一个模块的输出，不反向引用
- **零拷贝优先**：Token 阶段使用 `string_view` 直接引用原始输入，避免内存分配
- **所有权清晰**：每个阶段产出的数据有明确的所有权转移链

---

## 处理管线

### 阶段 1：词法分析（Tokenizer）

**输入**：原始 HTML 字符串（`std::string_view`）
**输出**：Token 序列（`std::vector<Token>`）

```
"<b>Hello <i>world</i></b>"
  → [START_TAG("b"), TEXT("Hello "), START_TAG("i"), TEXT("world"), END_TAG("i"), END_TAG("b")]
```

- 手写 15 状态有限状态机
- 零拷贝：Token 的 `raw`、`tag_name`、`attributes` 全部是 `string_view`，直接指向原始 HTML
- `<script>`、`<style>`、`<noscript>` 整体跳过（不产生任何 Token）
- `<!-- -->` 注释静默跳过
- 非法 `<` 回退为纯文本

**文件**：`core/src/tokenizer.h`、`core/src/tokenizer.cpp`

---

### 阶段 2：AST 构建（TreeBuilder）

**输入**：Token 序列
**输出**：AST 树（`ASTNode`）

```
[START_TAG("b"), TEXT("Hello "), START_TAG("i"), TEXT("world"), END_TAG("i"), END_TAG("b")]
  → ROOT
      └─ ELEMENT("b")
           ├─ TEXT("Hello ")
           └─ ELEMENT("i")
                └─ TEXT("world")
```

- 栈式构建：`START_TAG` 压栈，`END_TAG` 弹栈
- Void 元素（`<br>`、`<img>`、`<hr>` 等）不入栈，直接作为叶子节点
- 自动纠错：乱序嵌套时在栈中查找匹配、未闭合标签自动补齐、多余闭合标签忽略
- 嵌套深度限制（默认 256 层），超出截断不崩溃

**文件**：`core/src/tree_builder.h`、`core/src/tree_builder.cpp`

---

### 阶段 3+4：样式解析 + 实体解码（StyleResolver + EntityDecoder）

**输入**：AST 树
**输出**：`FlattenResult`（纯文本 + byte offset 样式区间）

```
AST: ROOT → ELEMENT("b") → TEXT("Hello &amp; World")
  → text: "Hello & World"
  → spans: [{byte_start:0, byte_end:17, tag:BOLD}]
```

StyleResolver 通过 DFS 遍历 AST，同时完成以下工作：

1. **HTML 实体解码**：调用 `EntityDecoder::decode()` 处理 TEXT 节点中的 `&amp;`、`&#60;`、`&#x3c;` 等
2. **空白折叠**：非 `<pre>` 内连续空白折叠为单个空格；`<pre>` 内空白原样保留
3. **标签映射**：`<b>`→BOLD、`<strong>`→BOLD、`<i>`→ITALIC、`<em>`→ITALIC 等
4. **属性提取**：`<a>` 的 `href`、`<img>` 的 `src`、`<source>` 的 `src`
5. **`<source>` 上下文感知**：通过父标签栈判定 `<source>` 在 `<video>` 内还是 `<audio>` 内
6. **CSS 行内样式解析**：解析 `style` 属性中的 `color`、`font-size` 等，生成独立的 style span
7. **值标准化**：颜色名称→HEX、em/rem/pt→px

**Span 顺序**：outside-in（外层 span 在前，内层 span 在后），例如 `<b><i>text</i></b>` 产生 `[BOLD, ITALIC]`。

**文件**：`core/src/style_resolver.h`、`core/src/style_resolver.cpp`、`core/src/entity_decoder.h`、`core/src/entity_decoder.cpp`

---

### 阶段 5：UTF-16 索引映射（UTF16Indexer）

**输入**：纯文本（UTF-8）
**输出**：byte offset → UTF-16 码元索引 的映射表

```
"Hi你好😊"  (UTF-8: 2+6+4=12 bytes)
byte 0 → utf16 0  (H)
byte 2 → utf16 2  (你)
byte 5 → utf16 3  (好)
byte 8 → utf16 4  (😊, surrogate pair 占 2 码元)
byte 12 → utf16 6
```

- 单趟扫描 UTF-8 文本，根据首字节判断序列长度（1/2/3/4 字节）
- 4 字节 UTF-8 字符（如 Emoji）映射为 2 个 UTF-16 码元（surrogate pair）
- 查询时使用 `std::lower_bound` 二分查找

**文件**：`core/src/utf16_indexer.h`、`core/src/utf16_indexer.cpp`

---

### 阶段 6：管线编排（Parser）

**职责**：将上述 5 个阶段串联，组装最终 `XMResult`。

```
Tokenizer → tokens
TreeBuilder → AST
StyleResolver → FlattenResult{text, spans[byte_offset]}
UTF16Indexer → byte_to_utf16 映射
→ XMSpan{range[utf16_index], tag, style, value}
→ XMResult{text, spans}
```

**文件**：`core/src/parser.h`、`core/src/parser.cpp`

---

### API 层（api.cpp）

**职责**：`extern "C"` 薄封装，将 C++ `ParserInternal` 类暴露为 C 风格不透明指针。

**文件**：`core/src/api.cpp`

---

## 数据流图

```
HTML 字符串
    │
    ▼
┌─────────────────────┐
│    Tokenizer         │  零拷贝 string_view
│  HTML → Token[]      │
└─────────┬───────────┘
          │ Token{TEXT, START_TAG, END_TAG, SELF_CLOSING_TAG}
          ▼
┌─────────────────────┐
│    TreeBuilder       │  栈式构建 + 自动纠错
│  Token[] → ASTNode   │
└─────────┬───────────┘
          │ ASTNode{ROOT, ELEMENT, TEXT}
          ▼
┌─────────────────────┐
│    StyleResolver     │  DFS + EntityDecoder + CSS 解析
│  ASTNode → Flatten   │
│  {text, spans[]}     │  text: 解码后纯文本（UTF-8）
└─────────┬───────────┘  spans: byte_offset 区间
          │
          ▼
┌─────────────────────┐
│    UTF16Indexer      │  byte_offset → utf16_index
│  text → 映射表       │
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│    Parser            │  组装 XMResult
│  byte spans →        │
│  utf16 XMSpan[]      │
└─────────┬───────────┘
          │
          ▼
    XMResult{
      error,
      text,        // UTF-8 纯文本
      text_len,
      spans[],     // UTF-16 索引区间
      span_count
    }
```

---

## 关键设计决策

### 1. 为什么用 UTF-8 内部处理 + UTF-16 索引输出？

- **UTF-8 内部**：`std::string_view` 零拷贝直接引用原始 HTML，状态机逐字节扫描性能最优
- **UTF-16 输出**：Java（`char`）、Swift（`String.Index` 底层 UTF-16）、ArkTS（`string`）原生编码都是 UTF-16。桥接层直接用 `start`/`end` 索引操作 `NSAttributedString` / `SpannableStringBuilder` / `StyledString`，无需二次转换

### 2. 为什么 `extern "C"` 而不是 C++ 接口？

- JNI（Android）和 N-API（Node.js）都要求 C 链接约定
- Swift 可以通过 Bridging Header 直接调用 C 函数
- C ABI 稳定，不会因 C++ 编译器版本或标准库差异导致二进制不兼容

### 3. 为什么 `<source>` 的 XMTagType 需要父标签栈？

`<source>` 标签本身无法区分上下文：
```html
<video><source src="a.mp4"></video>  → XM_TAG_VIDEO_SOURCE
<audio><source src="a.mp3"></audio>  → XM_TAG_AUDIO_SOURCE
```
StyleResolver 维护 `parent_stack_`，遇到 `<source>` 时回溯栈顶判定父标签。

### 4. 为什么 `<pre>` 内空白要保留？

富文本编辑器中的代码块需要精确的缩进和换行。如果折叠空白，代码格式会丢失。StyleResolver 的 `dfs()` 方法传递 `inside_pre` 标志控制空白处理策略。

### 5. 为什么 span 顺序是 outside-in？

`<b><i>text</i></b>` 产生 `[BOLD(0-4), ITALIC(0-4)]`。这样桥接层可以按顺序应用样式，外层样式先创建属性，内层样式叠加修改。

---

## 测试策略

### 测试矩阵

| 模块 | 测试文件 | 测试数 | 覆盖范围 |
|------|----------|--------|----------|
| Tokenizer | `test_tokenizer.cpp` | 16 | 纯文本、开始/闭合/自闭合标签、属性引号、非法输入、注释跳过、脚本跳过、混合内容 |
| TreeBuilder | `test_tree_builder.cpp` | 9 | 简单嵌套、深层嵌套、兄弟节点、乱序纠错、未闭合、多余闭合、void 元素、深度限制 |
| EntityDecoder | `test_entity_decoder.cpp` | 7 | 命名实体、十进制/十六进制数字实体、混合文本、不完整实体、空输入 |
| StyleResolver | `test_style_resolver.cpp` | 19 | 标签映射、别名映射、嵌套叠加、属性提取、pre 空白保留、CSS 颜色/字号、source 上下文 |
| UTF16Indexer | `test_utf16_indexer.cpp` | 5 | 纯 ASCII、中文、Emoji、混合内容、空字符串 |
| API 集成 | `test_api.cpp` | 29 | 完整管线、纠错、实体解码、CSS 标准化、错误查询、性能、恶意输入、线程安全 |

### 构建模式

- **Debug**：日常开发，`-Werror` 严格编译
- **Release**：性能验证
- **ASAN + UBSan**：内存安全验证

---

## 扩展指南

### 添加新标签支持

1. **`xmarkup.h`**：在 `XMTagType` 枚举中添加新值
2. **`style_resolver.cpp`**：在 `tag_map()` 中添加 `{"tagname", XM_TAG_XXX}` 映射
3. **编写测试**：在 `test_style_resolver.cpp` 和 `test_api.cpp` 中添加测试用例

### 添加新 CSS 属性支持

1. **`xmarkup.h`**：在 `XMStyleType` 枚举中添加新值
2. **`style_resolver.cpp`**：在 `add_style_spans()` 方法中添加属性名匹配和标准化逻辑
3. **编写测试**：在 `test_style_resolver.cpp` 和 `test_api.cpp` 中添加测试用例

### 添加新 HTML 实体

1. **`entity_decoder.cpp`**：在 `named_entities()` 映射表中添加 `{name, utf8_value}` 条目
2. **编写测试**：在 `test_entity_decoder.cpp` 中添加测试用例

---

## 子项目 B 路线图

核心引擎稳定后，启动三端桥接层开发。

### iOS（Swift 6+ / Xcode 26+）

```
XMarkup C API → Bridging Header → Swift 封装 → NSAttributedString
```

- 通过 Bridging Header 直接调用 C API
- 将 `XMSpan` 转换为 `NSAttributedString` 的属性范围
- UTF-16 索引直接映射到 `NSString.range`

### Android（Java / Kotlin）

```
XMarkup C API → JNI → Kotlin 封装 → SpannableStringBuilder
```

- JNI 封装 `xmarkup_parse` 返回的对象
- 将 `XMSpan` 转换为 `CharacterStyle` 子类（`StyleSpan`、`ForegroundColorSpan` 等）
- UTF-16 索引直接映射到 `Spannable.setSpan()`

### 鸿蒙（ArkTS）

```
XMarkup C API → N-API → ArkTS 封装 → StyledString / RichText
```

- 通过 N-API 桥接 C API
- 将 `XMSpan` 转换为 `StyledString` 的样式配置
- UTF-16 索引直接映射到 ArkTS `string` 索引

### 共同原则

1. 每个桥接层是独立的库/模块
2. 桥接层只负责 **类型映射** 和 **生命周期管理**，不做任何解析逻辑
3. 所有解析逻辑在 C++ 核心引擎中完成，桥接层是薄封装
4. 桥接层的内存模型：每次调用 `xmarkup_parse` 获取结果，桥接层负责将数据拷贝到平台原生类型后调用 `xmarkup_result_free`
