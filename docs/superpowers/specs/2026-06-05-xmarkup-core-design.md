# XMarkup C++ 核心解析引擎设计规格说明书

> 子项目 A：C++17 核心引擎 + CMake 构建 + 单元测试
> 日期：2026-06-05
> 状态：待用户审查

---

## 1. 概述

XMarkup 是一个从零构建的高性能、线程安全的 HTML 富文本解析引擎。本文档定义**子项目 A（C++ 核心引擎）**的完整设计。子项目 B（三端桥接层）将在核心引擎稳定后另设规格。

### 核心目标

- 统一 iOS、Android、鸿蒙三端的 HTML 解析逻辑
- 消除各平台原生 HTML 转 富文本 API 的性能瓶颈、内存泄漏及超长文本崩溃风险
- 实现"一套解析核心，多端原生渲染"

### 关键决策记录

| 决策项 | 选定方案 | 理由 |
|--------|---------|------|
| 解析器策略 | 从零手写 | 完全掌控代码，针对富文本场景极致精简 |
| HTML 覆盖范围 | 移动端富文本实用子集 | 覆盖 99% 场景，状态机只需 15 个状态 |
| 词法分析器 | 手写有限状态机 | O(N) 单趟扫描，零拷贝，性能远优于正则 |
| 内部编码 | UTF-8 全链路 | string_view 零拷贝，状态机逐字节扫描最优 |
| 输出编码 | TextRange 使用 UTF-16 索引 | Java/Swift/ArkTS 原生编码，无缝对接 |
| C++ API 风格 | extern "C" 扁平接口 | JNI/N-API/Swift 通用，ABI 稳定 |
| 项目结构 | 单仓 + 目录隔离 | 一人开发，联调方便 |
| 测试框架 | GoogleTest | 死亡测试适合验证崩溃安全性 |

---

## 2. 项目目录结构

```
XMarkup/
├── CMakeLists.txt                    # 顶层 CMake
├── CLAUDE.md                         # 项目规则
│
├── core/                             # C++17 核心引擎
│   ├── include/
│   │   └── xmarkup/
│   │       └── xmarkup.h             # 唯一公共头文件（C 风格 API）
│   ├── src/
│   │   ├── tokenizer.h               # 状态机词法分析器（内部头文件）
│   │   ├── tokenizer.cpp
│   │   ├── tree_builder.h            # 栈式 AST 构建器（含 <pre> 追踪）
│   │   ├── tree_builder.cpp
│   │   ├── style_resolver.h          # CSS 行内样式解析 + 映射（含父标签栈）
│   │   ├── style_resolver.cpp
│   │   ├── entity_decoder.h          # HTML 实体解码器
│   │   ├── entity_decoder.cpp
│   │   ├── utf16_indexer.h           # UTF-8 → UTF-16 索引映射器
│   │   ├── utf16_indexer.cpp
│   │   ├── parser.h                  # Parser 内部实现（C++ 类）
│   │   ├── parser.cpp
│   │   └── api.cpp                   # extern "C" API 薄封装层
│   └── CMakeLists.txt                # 编译为静态库 xmarkup_core
│
├── tests/                            # GoogleTest 单元测试
│   ├── CMakeLists.txt
│   ├── test_tokenizer.cpp
│   ├── test_tree_builder.cpp
│   ├── test_style_resolver.cpp
│   ├── test_entity_decoder.cpp
│   ├── test_utf16_indexer.cpp
│   ├── test_api.cpp
│   └── test_data/                    # 测试用 HTML 文件
│       ├── simple.html
│       ├── nested_mismatch.html
│       ├── stress_50kb.html
│       └── malicious.html
│
├── platforms/                          # 三端桥接层（子项目 B 预留）
│   ├── ios/
│   ├── android/
│   └── harmony/
│
└── docs/
    └── superpowers/
        └── specs/
```

---

## 3. 核心数据结构（C API）

### 3.1 公共头文件 `xmarkup.h`

```c
#ifndef XMARKUP_H
#define XMARKUP_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* 样式枚举 */
typedef enum XMTagType {
    XM_TAG_UNKNOWN       = 0,
    /* 文本样式 */
    XM_TAG_BOLD          = 1,
    XM_TAG_ITALIC        = 2,
    XM_TAG_UNDERLINE     = 3,
    XM_TAG_STRIKETHROUGH = 4,
    XM_TAG_SUBSCRIPT     = 5,
    XM_TAG_SUPERSCRIPT   = 6,
    XM_TAG_MARK          = 7,
    XM_TAG_CODE          = 8,
    /* 段落结构 */
    XM_TAG_PARAGRAPH     = 20,
    XM_TAG_HEADING_1     = 21,
    XM_TAG_HEADING_2     = 22,
    XM_TAG_HEADING_3     = 23,
    XM_TAG_HEADING_4     = 24,
    XM_TAG_HEADING_5     = 25,
    XM_TAG_HEADING_6     = 26,
    XM_TAG_BLOCKQUOTE    = 27,
    XM_TAG_PREFORMATTED  = 28,
    /* 链接与媒体 */
    XM_TAG_LINK          = 40,
    XM_TAG_IMAGE         = 41,
    XM_TAG_VIDEO         = 42,
    XM_TAG_VIDEO_SOURCE  = 43,
    XM_TAG_AUDIO         = 44,
    XM_TAG_AUDIO_SOURCE  = 45,
    /* 列表 */
    XM_TAG_LIST_ORDERED   = 50,
    XM_TAG_LIST_UNORDERED = 51,
    XM_TAG_LIST_ITEM      = 52,
    /* 表格 */
    XM_TAG_TABLE         = 60,
    XM_TAG_TABLE_ROW     = 61,
    XM_TAG_TABLE_CELL    = 62,
    XM_TAG_TABLE_HEADER  = 63,
    /* 其他 */
    XM_TAG_HORIZONTAL_RULE = 70,
    XM_TAG_LINE_BREAK    = 71,
    XM_TAG_DIVISION      = 72,
    XM_TAG_SPAN          = 73,
} XMTagType;

/* CSS 样式属性 */
typedef enum XMStyleType {
    XM_STYLE_FOREGROUND_COLOR = 1,
    XM_STYLE_BACKGROUND_COLOR = 2,
    XM_STYLE_FONT_SIZE        = 3,
    XM_STYLE_FONT_WEIGHT      = 4,
    XM_STYLE_FONT_STYLE       = 5,
    XM_STYLE_TEXT_DECORATION   = 6,
    XM_STYLE_LINE_HEIGHT      = 7,
    XM_STYLE_TEXT_ALIGN       = 8,
    XM_STYLE_LETTER_SPACING   = 9,
    XM_STYLE_MEDIA_TYPE       = 10,  // 媒体 MIME 类型（video/audio source）
    XM_STYLE_MEDIA_QUERY      = 11,  // 媒体查询条件（source 的 media 属性）
} XMStyleType;

/* 文本区间（UTF-16 索引） */
typedef struct XMRange {
    uint32_t start;
    uint32_t end;
} XMRange;

/* 样式单元 */
typedef struct XMSpan {
    XMRange     range;
    XMTagType   tag;
    XMStyleType style;
    const char* value;
    uint32_t    value_len;
} XMSpan;

/* 解析结果 */
typedef struct XMResult {
    XMError       error;       // 错误码，XM_OK 表示成功
    const char*   text;        // 清洗后的纯文本（UTF-8，以 \0 结尾）
    uint32_t      text_len;    // text 的字节长度
    const XMSpan* spans;       // 样式区间数组
    uint32_t      span_count;  // spans 数组长度
} XMResult;

/* 配置 */
typedef struct XMConfig {
    uint8_t  enable_autocorrect;   // 是否启用乱序嵌套自动纠错（默认 1）
    uint16_t max_nesting_depth;    // 最大嵌套深度（默认 256，防 DoS）
    uint16_t base_font_size;       // 基准字体大小，单位 px（默认 16，用于 em/rem/pt 换算）
} XMConfig;

/* 错误码 */
typedef enum XMError {
    XM_OK               = 0,    // 成功
    XM_ERR_NULL_PARSER  = -1,   // parser 为 NULL
    XM_ERR_NULL_INPUT   = -2,   // html 为 NULL（length > 0 时）
    XM_ERR_NESTING_OVERFLOW = -3, // 嵌套深度超限，已截断
    XM_ERR_ALLOC_FAILED = -4,   // 内存分配失败
} XMError;

/* 不透明解析器句柄 */
typedef struct XMParser XMParser;

/* 生命周期 */
XMParser* xmarkup_create(const XMConfig* config);
void      xmarkup_destroy(XMParser* parser);

/* 核心解析 */
XMResult* xmarkup_parse(XMParser* parser, const char* html, size_t length);
void      xmarkup_result_free(XMResult* result);

/* 错误查询（线程安全，返回最近一次 xmarkup_parse 的错误码） */
XMError xmarkup_last_error(XMParser* parser);
const char* xmarkup_error_string(XMError error);

#ifdef __cplusplus
}
#endif

#endif /* XMARKUP_H */
```

### 3.2 数据契约说明

| 结构体 | 职责 | 内存归属 |
|--------|------|---------|
| `XMParser` | 解析器实例，持有配置和内部状态 | 由 `xmarkup_create` 分配，`xmarkup_destroy` 释放 |
| `XMResult` | 解析结果，含错误码 + 纯文本 + 样式数组 | 由 `xmarkup_parse` 分配，`xmarkup_result_free` 释放 |
| `XMSpan` | 样式区间，扁平数组元素 | 隶属于 `XMResult`，随 `XMResult` 一起释放 |
| `XMConfig` | 配置参数 | 调用者栈分配或堆分配，仅在使用时读取 |

---

## 4. 模块设计

### 4.1 状态机词法分析器（Tokenizer）

#### 状态定义（15 个）

| 状态 | 描述 | 输入触发转换 |
|------|------|-------------|
| `DATA` | 纯文本状态 | `'<'` → `TAG_OPEN` |
| `TAG_OPEN` | 读到 `<` | alpha → `TAG_NAME`；`'/'` → `END_TAG_OPEN`；`'!'` → `COMMENT` |
| `TAG_NAME` | 读取标签名 | whitespace → `BEFORE_ATTR_NAME`；`'>'` → `DATA`；`'/'` → `SELF_CLOSING` |
| `END_TAG_OPEN` | 闭合标签 | alpha → `TAG_NAME` |
| `BEFORE_ATTR_NAME` | 属性区前 | alpha/`'-'` → `ATTR_NAME`；`'>'` → `DATA`；`'/'` → `SELF_CLOSING` |
| `ATTR_NAME` | 读取属性名 | `'='` → `AFTER_ATTR_NAME`；whitespace → `BEFORE_ATTR_NAME` |
| `AFTER_ATTR_NAME` | 属性名后 | `'"'` → `ATTR_VALUE_DOUBLE_Q`；`"'"` → `ATTR_VALUE_SINGLE_Q`；其他 → `ATTR_VALUE_UNQUOTED` |
| `ATTR_VALUE_DOUBLE_Q` | 双引号属性值 | `'"'` → `BEFORE_ATTR_NAME` |
| `ATTR_VALUE_SINGLE_Q` | 单引号属性值 | `"'"` → `BEFORE_ATTR_NAME` |
| `ATTR_VALUE_UNQUOTED` | 无引号属性值 | whitespace → `BEFORE_ATTR_NAME`；`'>'` → `DATA` |
| `SELF_CLOSING` | 自闭合斜杠 | `'>'` → `DATA`（发射 SELF_CLOSING_TAG） |
| `COMMENT` | 注释状态 | `"-->"` → `DATA`（不发射 Token） |

#### Token 类型

```cpp
enum class TokenType {
    TEXT,              // 纯文本片段
    START_TAG,         // 开始标签
    END_TAG,           // 闭合标签
    SELF_CLOSING_TAG,  // 自闭合标签
    COMMENT,           // 注释（内部使用，不输出）
};

struct Token {
    TokenType        type;
    std::string_view raw;        // 零拷贝，指向原始 HTML 缓冲区
    std::string_view tag_name;   // 仅 START_TAG / END_TAG 有效
    std::string_view attributes; // 属性区域原始切片，延迟解析
};
```

#### 关键优化

1. **零拷贝**：所有 `string_view` 直接指向输入缓冲区，词法分析阶段零内存分配
2. **字符批量化**：`DATA` 状态下连续普通字符合并为单个 TEXT Token，减少 80%+ Token 数量
3. **未知标签透明**：不认识的标签名仍然正确解析，标签名存入 `tag_name` 交由下游处理
4. **注释丢弃**：`<!-- -->` 内容直接跳过，不产生 Token

#### 防御性边界

- `<` 后跟数字（如 `<3`）视为普通文本
- 未闭合的 `<` 读到输入末尾，将剩余内容作为 TEXT Token 输出
- 空输入返回空 Token 序列

---

### 4.2 栈式 AST 构建器（Tree Builder）

#### AST 节点

```cpp
struct ASTNode {
    enum Type { ROOT, ELEMENT, TEXT };
    Type                 type;
    std::string_view     tag_name;
    std::string_view     attributes;
    std::string_view     text;
    std::vector<ASTNode> children;
};
```

#### 自动纠错规则

| 场景 | 输入示例 | 纠错行为 |
|------|---------|---------|
| 乱序嵌套 | `<a><b></a></b>` | 先闭合 `<b>`，闭合 `<a>`，重开 `<b>` |
| 未闭合标签 | `<div><p>text` | 文档末尾自动补齐 `</p></div>` |
| 多余闭合标签 | `</b>text` | 忽略无匹配的 `</b>`，保留文本 |
| 自闭合标签 | `<br>`, `<img>` | 不入栈，直接作为叶子节点 |
| 嵌套超限 | 超过 max_nesting_depth | 截断超出层级，文本保留 |

#### void 元素列表（不入栈）

```
br, hr, img, input, meta, link, col, area, base, embed, source, track, wbr
```

#### AST 到 ParsedResult 的展平

通过一次深度优先遍历（DFS）：
1. 收集纯文本，拼接为连续 UTF-8 字符串
2. 记录每个 AST 节点对应的文本区间（byte offset）
3. 交给 UTF-16 索引器转换
4. 组装 `XMResult`

#### `<pre>` 空白保留

TreeBuilder 在构建 AST 时追踪当前是否处于 `<pre>` 节点内部：

```cpp
// DFS 遍历时维护
bool inside_pre_ = false;

// 进入 <pre> 节点时
if (tag_name == "pre") inside_pre_ = true;

// 收集文本时
if (inside_pre_) {
    // 原样保留所有空白、换行、连续空格
} else {
    // 标准空白折叠：连续空白合并为单个空格
}

// 离开 <pre> 节点时
if (tag_name == "pre") inside_pre_ = false;
```

---

### 4.3 样式解析器（Style Resolver）

#### 父标签栈与上下文感知

StyleResolver 在 DFS 遍历 AST 时维护一个**父标签栈**，用于解决上下文依赖的标签映射：

```cpp
std::vector<std::string_view> parent_stack_;

// 进入节点时压栈
parent_stack_.push_back(node.tag_name);

// 遇到 <source> 时查询栈顶父标签
if (tag_name == "source") {
    auto parent = parent_stack_.size() >= 2
        ? parent_stack_[parent_stack_.size() - 2]  // source 自身已在栈顶，父标签是前一个
        : "";
    if (parent == "video")  → XM_TAG_VIDEO_SOURCE
    if (parent == "audio")  → XM_TAG_AUDIO_SOURCE
    else                    → XM_TAG_UNKNOWN  // 容错
}

// 离开节点时弹栈
parent_stack_.pop_back();
```

#### 标签语义映射

| HTML 标签 | XMTagType | 备注 |
|-----------|-----------|------|
| `<b>`, `<strong>` | `XM_TAG_BOLD` | 多对一映射 |
| `<i>`, `<em>` | `XM_TAG_ITALIC` | 多对一映射 |
| `<u>`, `<ins>` | `XM_TAG_UNDERLINE` | 多对一映射 |
| `<s>`, `<strike>`, `<del>` | `XM_TAG_STRIKETHROUGH` | 多对一映射 |
| `<a href>` | `XM_TAG_LINK` | value = href 值 |
| `<img src>` | `XM_TAG_IMAGE` | value = src 值 |
| `<video>` | `XM_TAG_VIDEO` | value = poster（封面图），子 source 独立输出 |
| `<audio>` | `XM_TAG_AUDIO` | 与 video 对称 |
| `<source>` (在 video 内) | `XM_TAG_VIDEO_SOURCE` | 通过父标签栈判定上下文 |
| `<source>` (在 audio 内) | `XM_TAG_AUDIO_SOURCE` | 通过父标签栈判定上下文 |
| `<source>` (其他位置) | `XM_TAG_UNKNOWN` | 容错处理 |
| `<h1>`~`<h6>` | `XM_TAG_HEADING_1`~`6` | |
| `<p>` | `XM_TAG_PARAGRAPH` | |
| `<ul>`, `<ol>`, `<li>` | `XM_TAG_LIST_*` | |
| `<table>`, `<tr>`, `<td>`, `<th>` | `XM_TAG_TABLE_*` | |
| `<br>` | `XM_TAG_LINE_BREAK` | void 元素 |
| `<hr>` | `XM_TAG_HORIZONTAL_RULE` | void 元素 |
| 未知标签 | `XM_TAG_UNKNOWN` | 内部文本保留 |

#### CSS 行内样式解析

支持属性：`color`, `background-color`, `background`, `font-size`, `font-weight`, `font-style`, `text-decoration`, `line-height`, `text-align`, `letter-spacing`

#### 值标准化规则

**颜色值：**

| 输入格式 | 标准化输出 | 示例 |
|---------|-----------|------|
| 颜色名 | `#RRGGBB` | `red` → `#FF0000` |
| `rgb(r,g,b)` | `#RRGGBB` | `rgb(255,0,0)` → `#FF0000` |
| `rgba(r,g,b,a)` | `#RRGGBBAA` | `rgba(255,0,0,0.5)` → `#FF000080` |
| `#RGB` | `#RRGGBB` | `#F00` → `#FF0000` |

**font-size 值（统一换算为 px 数值）：**

| 输入格式 | 换算规则 | 示例（base_font_size=16） |
|---------|---------|--------------------------|
| `16px` | 直接取数值 | `16px` → `16` |
| `1.5em` | 数值 × base_font_size | `1.5em` → `24` |
| `1.5rem` | 数值 × base_font_size | `1.5rem` → `24` |
| `12pt` | 数值 × 1.333（pt→px） | `12pt` → `16` |
| `100%` | 数值 / 100 × base_font_size | `150%` → `24` |
| 无单位数字 | 原值透传（可能是行高倍数） | `1.5` → `1.5` |

> `base_font_size` 默认值为 16（px），通过 `XMConfig.base_font_size` 可配置。
> 桥接层拿到 px 数值后，根据本平台的屏幕密度和字体缩放因子做最终适配。

**其他值：**

| 输入格式 | 标准化输出 | 示例 |
|---------|-----------|------|
| `bold` / `700` | `bold` | font-weight 标准化 |
| `italic` | `italic` | font-style 直接透传 |
| `underline` / `line-through` | 原值 | text-decoration 直接透传 |
| `left` / `center` / `right` / `justify` | 原值 | text-align 直接透传 |
| `1.5` / `24px` | 数值部分 | line-height / letter-spacing |

---

### 4.4 HTML 实体解码器（Entity Decoder）

#### 设计目标

在 DFS 展平 AST 时，对文本节点中的 HTML 实体进行解码，确保输出的纯文本中不包含任何原始实体引用。

#### 支持的实体类型

| 类型 | 格式 | 示例 | 解码结果 |
|------|------|------|---------|
| 命名实体 | `&name;` | `&amp;` | `&` |
| 十进制数字实体 | `&#NNN;` | `&#60;` | `<` |
| 十六进制数字实体 | `&#xHHH;` | `&#x4e2d;` | `中` |

#### 常用命名实体映射表

```cpp
// 内置约 120 个常用 HTML 命名实体，包括但不限于：
{"amp",   '&'},
{"lt",    '<'},
{"gt",    '>'},
{"quot",  '"'},
{"apos",  '\''},
{"nbsp",  '\xC2\xA0'},   // U+00A0 NO-BREAK SPACE
{"copy",  '©'},
{"reg",   '®'},
{"trade", '™'},
{"mdash", '—'},
{"ndash", '–'},
{"laquo", '«'},
{"raquo", '»'},
// ... 完整列表约 120 项
```

#### 解码策略

```
输入文本节点: "1 &lt; 2 &amp; 3 &gt; 0 &#x4e2d;&#25991;"
                    │
                    ↓ 单趟扫描，遇到 & 开始解码
                    ↓ 查找 ; 结束
                    ↓ 查表 / 解析数字
                    ↓ 替换为对应 UTF-8 字符
                    ↓
输出纯文本: "1 < 2 & 3 > 0 中文"
```

**关键实现要点：**

1. **在 DFS 展平时内联解码**：不需要单独的解码步骤，在遍历 AST 文本节点时同步解码
2. **解码影响 byte offset**：实体引用（如 `&amp;` = 5 字节）解码为单字符 `&`（1 字节），Span 的 range 需要相应调整
3. **容错处理**：
   - 遇到 `&` 但后续不是合法实体 → 保留原始 `&` 字符，不丢弃
   - 遇到 `&` 但没有找到 `;` → 保留原始 `&` 及后续字符
   - 非法数字实体（如 `&#9999999;`）→ 替换为 Unicode 替换字符 U+FFFD

#### 对 Span 区间的影响

实体解码发生在 DFS 展平阶段，**在 UTF-16 索引映射之前**。因此 Span 的 byte offset 基于解码后的文本计算，UTF-16 索引器看到的是已经解码的纯文本。

```
HTML: "1 &lt; 2"       (原始 8 字节)
       ↓ 实体解码
Text: "1 < 2"          (解码后 5 字节)
       ↓ UTF-16 索引映射
Range: {0, 5}          (5 个 UTF-16 码元)
```

---

### 4.4 UTF-16 索引映射器

#### 算法：单趟双索引扫描

```cpp
struct ByteToUTF16 {
    uint32_t byte_offset;
    uint32_t utf16_offset;
};

class UTF16Indexer {
public:
    void build(std::string_view utf8_text);
    XMRange to_utf16_range(uint32_t byte_start, uint32_t byte_end) const;
private:
    std::vector<ByteToUTF16> mapping_;
};
```

#### 工作原理

1. 单趟扫描纯文本，在 UTF-8 序列长度变化处记录锚点
2. 查询时用二分查找定位最近锚点，线性推算目标偏移
3. 纯 ASCII 文本映射表只有起止两点，几乎零开销

#### 边界处理

| 场景 | 行为 |
|------|------|
| 纯 ASCII | byte offset == utf16 offset，极低开销 |
| 非法 UTF-8 | 跳过非法字节，视为 1→1 |
| 空文本 | 映射表为空，所有 range 为 {0,0} |
| Emoji（surrogate pair） | 正确计为 2 个 UTF-16 码元 |

---

## 5. 完整处理管线

```
HTML 字符串 (UTF-8)
       │
       ↓
┌──────────────┐
│  Tokenizer   │ 零拷贝状态机，15 个状态
│  (string_view)│ 输出 Token 序列
└──────┬───────┘
       │ Token[]
       ↓
┌──────────────┐
│ TreeBuilder  │ 栈式构建，自动纠错
│              │ 追踪 <pre> 上下文
│              │ 输出 AST（byte offset）
└──────┬───────┘
       │ AST
       ↓
┌──────────────┐
│StyleResolver │ DFS 遍历，标签映射 + CSS 解析
│  + Entity    │ 维护父标签栈（source 上下文感知）
│   Decoder    │ HTML 实体解码 → 纯文本
│              │ <pre> 内跳过空白折叠
│              │ 输出 text(UTF-8) + spans(byte offset)
└──────┬───────┘
       │ text + spans (byte offset)
       ↓
┌──────────────┐
│ UTF16Indexer │ 单趟扫描，byte → utf16 映射
│              │ 输出 spans (UTF-16 offset)
└──────┬───────┘
       │
       ↓
   XMResult
   { error, text(UTF-8), spans[](UTF-16 ranges) }
```

---

## 6. CMake 构建系统

### 顶层 CMakeLists.txt

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

### core/CMakeLists.txt

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

option(XMARKUP_BUILD_SHARED "Build shared library" OFF)
if(XMARKUP_BUILD_SHARED)
    add_library(xmarkup_shared SHARED $<TARGET_OBJECTS:xmarkup_core>)
endif()
```

### tests/CMakeLists.txt

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

### 构建命令

```bash
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
cd build && ctest --output-on-failure
```

---

## 7. 测试策略

### 测试覆盖矩阵

| 模块 | 正常用例 | 边界防御 | 性能测试 | 线程安全 |
|------|---------|---------|---------|---------|
| Tokenizer | 基本分词、属性解析、零拷贝验证 | 空输入、未闭合标签、非法字符、注释 | 字符批量化验证 | — |
| TreeBuilder | 正常嵌套、兄弟节点、`<pre>` 空白保留 | 乱序纠错、未闭合、多余闭合、深度限制 | 50KB 压力测试 < 15ms | — |
| StyleResolver | 标签映射、CSS 解析、值提取、`<source>` 上下文 | 未知标签、非法 CSS、空属性 | — | — |
| EntityDecoder | 命名实体、数字实体、十六进制实体 | 不完整实体、非法实体、未知命名实体 | — | — |
| UTF16Indexer | ASCII、中文、Emoji、混合内容 | 空文本、非法 UTF-8 | — | — |
| API 集成 | 完整管线、错误码验证 | NULL 输入、恶意输入、千万层嵌套 | 50KB 压力测试 | 多线程并发 |

---

## 8. 非功能性指标

| 指标 | 目标值 | 验证方式 |
|------|--------|---------|
| 解析性能 | 50KB HTML < 15ms | GoogleTest Stress 用例 + 计时 |
| 线程安全 | 多线程并发无数据竞争 | API 线程安全测试 |
| 崩溃率 | 任意畸形输入零崩溃 | 恶意 HTML 测试 + ASAN |
| 内存 | 无泄漏 | ASAN + Valgrind |
| 嵌套深度 | 默认 256 层上限，可配置 | MaxNestingDepth 测试 |
| 二进制体积 | 核心静态库 < 500KB | 构建产物检查 |

---

## 9. 与子项目 B 的接口边界

核心引擎通过 `xmarkup.h` 定义的 C API 与桥接层交互。桥接层需完成以下工作：

| 平台 | 接入方式 | 转化目标 |
|------|---------|---------|
| iOS | Swift 6+ 直接调用 C API | `NSAttributedString` |
| Android | JNI 调用 C API | `SpannableStringBuilder` |
| 鸿蒙 | N-API 调用 C API | ArkUI `StyledString` |

桥接层核心逻辑：
1. 调用 `xmarkup_parse()` 获取 `XMResult`
2. 读取 `text` 转为本平台字符串
3. 单次循环遍历 `spans[]`，将每个 `XMSpan` 映射为平台原生样式
4. 调用 `xmarkup_result_free()` 释放结果

---

## 10. 补充：特殊标签处理

### 10.1 跳过标签（内容不进入文本流）

以下标签及其内部内容在词法分析阶段**整体跳过**，不产生任何 Token：

- `<script>` ... `</script>`
- `<style>` ... `</style>`
- `<noscript>` ... `</noscript>`

### 10.2 策略

词法分析器在 `TAG_NAME` 状态识别到上述标签名后，进入专用的 `RAWTEXT` 状态，持续消费字符直到遇到对应的闭合标签，然后回到 `DATA` 状态。这避免了 `<script>` 内部的 `<` 被误解析为标签开始。

### 10.3 `<video>` 视频标签解析

#### 10.3.1 设计目标

视频标签的解析目标是**结构化提取所有视频源信息**，供三端桥接层根据平台能力选择最佳播放源。核心引擎只负责解析，不负责选择和渲染。

#### 10.3.2 支持的 HTML 写法

```html
<!-- 写法 1：直接 src -->
<video src="movie.mp4" poster="cover.jpg" controls></video>

<!-- 写法 2：多 source（不同格式/码率/分辨率） -->
<video poster="cover.jpg" controls>
  <source src="movie.mp4" type="video/mp4">
  <source src="movie.webm" type="video/webm">
  <source src="movie-hd.mp4" type="video/mp4" media="(min-width: 800px)">
</video>

<!-- 写法 3：直接 src + source 混合（罕见但需兼容） -->
<video src="fallback.mp4">
  <source src="movie.mp4" type="video/mp4">
</video>

<!-- 写法 4：无 src 也无 source（降级文本） -->
<video controls>您的浏览器不支持视频</video>
```

#### 10.3.3 Span 生成规则

`<video>` 标签在 AST 中作为容器节点，其子节点（`<source>` 和文本）在展平时按以下规则生成 Span：

**`<video>` 容器本身：**

| XMSpan 字段 | 值 | 说明 |
|-------------|---|------|
| `tag` | `XM_TAG_VIDEO` | 标识视频容器 |
| `style` | 0 | 无样式 |
| `value` | poster 属性值 | 封面图 URL，无 poster 时为 NULL |
| `range` | 视频标签对应的文本区间 | 通常为空区间（视频本身不产生文本） |

**`<source>` 每个子标签：**

| XMSpan 字段 | 值 | 说明 |
|-------------|---|------|
| `tag` | `XM_TAG_VIDEO_SOURCE` | 标识视频源 |
| `style` | 0 | 无样式 |
| `value` | src 属性值 | 视频地址 |
| `range` | 与父级 `<video>` 相同 | 关联到同一个位置 |

**关键属性提取：** `<source>` 的 `type` 属性（如 `video/mp4`）通过新增的 `XM_STYLE_MEDIA_TYPE` 携带：

```c
/* 新增 CSS 样式枚举值 */
typedef enum XMStyleType {
    /* ... 原有值 ... */
    XM_STYLE_MEDIA_TYPE     = 10,  // 媒体 MIME 类型，用于 <source> 标签
    XM_STYLE_MEDIA_QUERY    = 11,  // 媒体查询条件，用于 <source> 的 media 属性
} XMStyleType;
```

#### 10.3.4 完整示例

**输入 HTML：**

```html
<p>文字<video src="main.mp4" poster="cover.jpg"><source src="hd.mp4" type="video/mp4"><source src="hd.webm" type="video/webm"></video>更多文字</p>
```

**生成的纯文本 + Spans：**

```
text: "文字更多文字"

spans[0]: { range: {0, 6},  tag: XM_TAG_PARAGRAPH,      style: 0,                    value: NULL }
spans[1]: { range: {2, 2},  tag: XM_TAG_VIDEO,           style: 0,                    value: "cover.jpg" }
spans[2]: { range: {2, 2},  tag: XM_TAG_VIDEO,           style: XM_STYLE_MEDIA_TYPE,  value: "video/mp4" }
spans[3]: { range: {2, 2},  tag: XM_TAG_VIDEO_SOURCE,    style: XM_STYLE_MEDIA_TYPE,  value: "hd.mp4" }
spans[4]: { range: {2, 2},  tag: XM_TAG_VIDEO_SOURCE,    style: XM_STYLE_MEDIA_TYPE,  value: "hd.webm" }
```

**设计说明：**

- `<video>` 自身如果带 `src` 属性，生成一个额外的 `XM_TAG_VIDEO` span，其 value 为 src 值，作为**主视频源**
- 每个 `<source>` 生成独立的 `XM_TAG_VIDEO_SOURCE` span，value 为 src，`XM_STYLE_MEDIA_TYPE` 携带 MIME 类型
- 视频标签不产生文本内容，因此 range 为空区间 `{2, 2}`，但**位置信息保留**，桥接层知道视频在文本中的插入点
- `<video>` 内的降级文本（如"您的浏览器不支持视频"）**不进入纯文本流**——移动端不需要降级文本

#### 10.3.5 桥接层消费指南

核心引擎输出的 Span 结构已包含三端所需的全部信息，桥接层按以下策略消费：

```
1. 找到 XM_TAG_VIDEO span → 获取封面图 (value)
2. 收集所有 XM_TAG_VIDEO_SOURCE span → 获取 {src, type} 列表
3. 如果有 XM_TAG_VIDEO + src → 加入候选源列表作为兜底
4. 根据平台能力从候选列表中选择最佳源：
   - iOS: 优先 video/mp4 (AVPlayer 原生支持)
   - Android: 优先 video/mp4 (ExoPlayer/MediaPlayer)
   - 鸿蒙: 优先 video/mp4 (AVPlayer 原生支持)
5. 在 range.start 位置插入原生视频播放组件
```

#### 10.3.6 `<audio>` 音频标签（同步支持）

与 `<video>` 采用相同的解析策略：

```c
XM_TAG_AUDIO         = 44,
XM_TAG_AUDIO_SOURCE  = 45,
```

`<audio>` 标签处理逻辑与 `<video>` 完全对称，区别仅在于 tag 类型。Span 生成规则、source 提取逻辑完全复用 video 的代码路径。

---

## 11. 标签解析规范（输入→输出契约）

> 本章节为每个支持的 HTML 标签定义**明确的解析行为契约**。
> 所有单元测试必须以本章节的输入→输出对作为测试用例的权威来源。
> 如果代码行为与本章节不一致，以本章节为准。

### 约定

- `range` 中的数字均为 **UTF-16 码元索引**（`[start, end)`，左闭右开）
- `text` 为清洗后的纯文本，所有 HTML 标签已被剥离
- `value` 为 `NULL` 时表示该字段无值，省略不写
- 同一区间可以有多个 Span（语义叠加）

---

### 11.1 文本样式标签

#### `<b>` / `<strong>` → `XM_TAG_BOLD`

```
输入: <b>加粗</b>普通
text: "加粗普通"
spans:
  { range: {0, 2}, tag: XM_TAG_BOLD }
```

```
输入: <strong>加粗</strong>
text: "加粗"
spans:
  { range: {0, 2}, tag: XM_TAG_BOLD }    ← <strong> 与 <b> 映射相同
```

#### `<i>` / `<em>` → `XM_TAG_ITALIC`

```
输入: <i>斜体</i>
text: "斜体"
spans:
  { range: {0, 2}, tag: XM_TAG_ITALIC }
```

#### `<u>` / `<ins>` → `XM_TAG_UNDERLINE`

```
输入: <u>下划线</u>
text: "下划线"
spans:
  { range: {0, 3}, tag: XM_TAG_UNDERLINE }
```

#### `<s>` / `<strike>` / `<del>` → `XM_TAG_STRIKETHROUGH`

```
输入: <s>删除</s>
text: "删除"
spans:
  { range: {0, 2}, tag: XM_TAG_STRIKETHROUGH }
```

#### `<mark>` → `XM_TAG_MARK`

```
输入: <mark>高亮</mark>
text: "高亮"
spans:
  { range: {0, 2}, tag: XM_TAG_MARK }
```

#### `<code>` → `XM_TAG_CODE`

```
输入: <code>let x = 1</code>
text: "let x = 1"
spans:
  { range: {0, 9}, tag: XM_TAG_CODE }
```

#### `<sub>` → `XM_TAG_SUBSCRIPT`

```
输入: H<sub>2</sub>O
text: "H2O"
spans:
  { range: {1, 2}, tag: XM_TAG_SUBSCRIPT }
```

#### `<sup>` → `XM_TAG_SUPERSCRIPT`

```
输入: E=mc<sup>2</sup>
text: "E=mc2"
spans:
  { range: {4, 5}, tag: XM_TAG_SUPERSCRIPT }
```

#### 样式叠加（嵌套标签）

```
输入: <b><i>粗斜体</i></b>
text: "粗斜体"
spans:
  { range: {0, 3}, tag: XM_TAG_BOLD }
  { range: {0, 3}, tag: XM_TAG_ITALIC }   ← 同一区间多 Span 叠加
```

#### 行内样式叠加（标签 + CSS）

```
输入: <b style="color:#ff0000">红色粗体</b>
text: "红色粗体"
spans:
  { range: {0, 4}, tag: XM_TAG_BOLD,                          value: NULL }
  { range: {0, 4}, tag: 0,           style: XM_STYLE_FOREGROUND_COLOR, value: "#FF0000" }
```

---

### 11.2 段落结构标签

#### `<p>` → `XM_TAG_PARAGRAPH`

```
输入: <p>第一段</p><p>第二段</p>
text: "第一段第二段"
spans:
  { range: {0, 3}, tag: XM_TAG_PARAGRAPH }
  { range: {3, 6}, tag: XM_TAG_PARAGRAPH }
```

> 注意：段落之间是否插入换行由桥接层决定，核心引擎只输出区间。

#### `<h1>` ~ `<h6>` → `XM_TAG_HEADING_1` ~ `XM_TAG_HEADING_6`

```
输入: <h1>标题一</h1><h3>标题三</h3>
text: "标题一标题三"
spans:
  { range: {0, 3}, tag: XM_TAG_HEADING_1 }
  { range: {3, 6}, tag: XM_TAG_HEADING_3 }
```

#### `<blockquote>` → `XM_TAG_BLOCKQUOTE`

```
输入: <blockquote>引用内容</blockquote>
text: "引用内容"
spans:
  { range: {0, 4}, tag: XM_TAG_BLOCKQUOTE }
```

#### `<pre>` → `XM_TAG_PREFORMATTED`

```
输入: <pre>  保持  空格\n换行</pre>
text: "  保持  空格\n换行"     ← 内部空白原样保留
spans:
  { range: {0, 11}, tag: XM_TAG_PREFORMATTED }
```

> 注意：`<pre>` 内的连续空格和换行**原样保留**，不做折叠。

#### `<div>` → `XM_TAG_DIVISION`

```
输入: <div>内容A</div><div>内容B</div>
text: "内容A内容B"
spans:
  { range: {0, 3}, tag: XM_TAG_DIVISION }
  { range: {3, 6}, tag: XM_TAG_DIVISION }
```

#### `<span>` → `XM_TAG_SPAN`

```
输入: <span style="color:blue">蓝色文字</span>
text: "蓝色文字"
spans:
  { range: {0, 4}, tag: XM_TAG_SPAN }
  { range: {0, 4}, tag: 0,           style: XM_STYLE_FOREGROUND_COLOR, value: "#0000FF" }
```

---

### 11.3 链接与媒体标签

#### `<a href>` → `XM_TAG_LINK`

```
输入: <a href="https://example.com">链接文字</a>
text: "链接文字"
spans:
  { range: {0, 4}, tag: XM_TAG_LINK, value: "https://example.com" }
```

```
输入: <a href="https://example.com" style="color:#ff0000">红色链接</a>
text: "红色链接"
spans:
  { range: {0, 4}, tag: XM_TAG_LINK, value: "https://example.com" }
  { range: {0, 4}, tag: 0,           style: XM_STYLE_FOREGROUND_COLOR, value: "#FF0000" }
```

```
输入: <a name="anchor">锚点</a>              ← 无 href，只有 name
text: "锚点"
spans:
  { range: {0, 2}, tag: XM_TAG_LINK, value: NULL }     ← value 为空
```

#### `<img>` → `XM_TAG_IMAGE`

```
输入: 文字<img src="pic.jpg" alt="描述">更多文字
text: "文字更多文字"
spans:
  { range: {2, 2}, tag: XM_TAG_IMAGE, value: "pic.jpg" }
```

> 注意：`<img>` 是 void 元素，不产生文本。range 为空区间 `{2, 2}` 标记插入位置。
> `alt` 属性暂不输出到 span 中，桥接层可按需扩展。

---

### 11.4 列表标签

#### `<ul>` / `<ol>` / `<li>`

```
输入: <ul><li>苹果</li><li>香蕉</li></ul>
text: "苹果香蕉"
spans:
  { range: {0, 4}, tag: XM_TAG_LIST_UNORDERED }  ← UL 包裹整个列表
  { range: {0, 2}, tag: XM_TAG_LIST_ITEM }        ← 第一个 li
  { range: {2, 4}, tag: XM_TAG_LIST_ITEM }        ← 第二个 li
```

```
输入: <ol><li>第一</li><li>第二</li></ol>
text: "第一第二"
spans:
  { range: {0, 4}, tag: XM_TAG_LIST_ORDERED }     ← OL 包裹整个列表
  { range: {0, 2}, tag: XM_TAG_LIST_ITEM }         ← 第一个 li
  { range: {2, 4}, tag: XM_TAG_LIST_ITEM }         ← 第二个 li
```

```
输入: <ul><li>水果<ul><li>苹果</li><li>香蕉</li></ul></li></ul>
text: "水果苹果香蕉"
spans:
  { range: {0, 6}, tag: XM_TAG_LIST_UNORDERED }   ← 外层 UL
  { range: {0, 6}, tag: XM_TAG_LIST_ITEM }         ← 外层 li 包裹全部
  { range: {2, 6}, tag: XM_TAG_LIST_UNORDERED }   ← 内层 UL
  { range: {2, 4}, tag: XM_TAG_LIST_ITEM }         ← 内层 li: 苹果
  { range: {4, 6}, tag: XM_TAG_LIST_ITEM }         ← 内层 li: 香蕉
```

> 注意：列表项之间的分隔符（如"• "或"1. "）由桥接层根据 tag 类型决定，核心引擎不生成。
> 列表容器（`<ul>`/`<ol>`）的 range **始终包裹其全部子项**，与 `<table>` 的语义一致。

---

### 11.5 表格标签

#### `<table>` / `<tr>` / `<td>` / `<th>`

```
输入: <table><tr><th>姓名</th><th>年龄</th></tr><tr><td>张三</td><td>25</td></tr></table>
text: "姓名年龄张三25"
spans:
  { range: {0, 8}, tag: XM_TAG_TABLE }
  { range: {0, 4}, tag: XM_TAG_TABLE_ROW }
  { range: {0, 2}, tag: XM_TAG_TABLE_HEADER }
  { range: {2, 4}, tag: XM_TAG_TABLE_HEADER }
  { range: {4, 8}, tag: XM_TAG_TABLE_ROW }
  { range: {4, 6}, tag: XM_TAG_TABLE_CELL }
  { range: {6, 8}, tag: XM_TAG_TABLE_CELL }
```

> 注意：表格的布局渲染（行列对齐、边框）完全由桥接层负责。核心引擎只输出文本 + 语义区间。

---

### 11.6 其他标签

#### `<br>` → `XM_TAG_LINE_BREAK`

```
输入: 第一行<br>第二行
text: "第一行第二行"
spans:
  { range: {3, 3}, tag: XM_TAG_LINE_BREAK }
```

> 注意：核心引擎输出连续文本。`<br>` 输出空区间标记位置，桥接层在此处插入换行符。

#### `<hr>` → `XM_TAG_HORIZONTAL_RULE`

```
输入: 上方内容<hr>下方内容
text: "上方内容下方内容"
spans:
  { range: {4, 4}, tag: XM_TAG_HORIZONTAL_RULE }
```

> 与 `<br>` 类似，空区间标记位置，桥接层插入水平分隔线组件。

---

### 11.7 未知标签（透明透传）

```
输入: <custom>内部文字</custom>
text: "内部文字"
spans:
  { range: {0, 4}, tag: XM_TAG_UNKNOWN }
```

```
输入: <article>文章内容<span>高亮</span></article>
text: "文章内容高亮"
spans:
  { range: {0, 6}, tag: XM_TAG_UNKNOWN }      ← <article> 映射为 UNKNOWN
  { range: {4, 6}, tag: XM_TAG_SPAN }          ← <span> 正常映射
```

> 未知标签的**内部文本保留**，嵌套的已知标签**正常解析**。

---

### 11.8 自动纠错场景

#### 乱序嵌套纠错

```
输入: <a>链接<b>粗体</a>文字</b>
text: "链接粗体文字"
spans:
  { range: {0, 4}, tag: XM_TAG_LINK }
  { range: {2, 4}, tag: XM_TAG_BOLD }
  { range: {4, 6}, tag: XM_TAG_BOLD }          ← 纠错后重新打开的 <b>
```

#### 未闭合标签自动补齐

```
输入: <div><p>段落
text: "段落"
spans:
  { range: {0, 2}, tag: XM_TAG_DIVISION }
  { range: {0, 2}, tag: XM_TAG_PARAGRAPH }     ← 末尾自动补齐 </p></div>
```

#### 多余闭合标签忽略

```
输入: </b>正常文字
text: "正常文字"
spans: (空)                                      ← </b> 被忽略，文字保留
```

#### 空输入

```
输入: (空字符串)
text: ""
spans: (空数组，span_count = 0)
```

---

### 11.9 HTML 实体解码

#### 命名实体

```
输入: <p>1 &lt; 2 &amp; 3 &gt; 0</p>
text: "1 < 2 & 3 > 0"
spans:
  { range: {0, 13}, tag: XM_TAG_PARAGRAPH }    ← 解码后文本长度变化，range 基于解码后计算
```

#### 数字实体（十进制 / 十六进制）

```
输入: <p>&#20013;&#25991; = &#x4e2d;&#x6587;</p>
text: "中文 = 中文"
spans:
  { range: {0, 7}, tag: XM_TAG_PARAGRAPH }
```

#### 不完整实体（容错）

```
输入: <p>&amp hello &unknown; end</p>
text: "& hello &unknown; end"     ← & 无分号保留原文，&unknown; 未知实体保留原文
spans:
  { range: {0, 20}, tag: XM_TAG_PARAGRAPH }
```

#### nbsp（不换行空格）

```
输入: <p>Hello&nbsp;World</p>
text: "Hello\xC2\xA0World"       ← U+00A0 NO-BREAK SPACE（非普通空格）
spans:
  { range: {0, 11}, tag: XM_TAG_PARAGRAPH }     ← UTF-16 中 nbsp 占 1 个码元
```

---

### 11.10 CSS 行内样式值标准化

| 输入 style 值 | 输出 value | XMStyleType |
|--------------|-----------|-------------|
| `color: red` | `#FF0000` | `XM_STYLE_FOREGROUND_COLOR` |
| `color: #F00` | `#FF0000` | `XM_STYLE_FOREGROUND_COLOR` |
| `color: rgb(255,0,0)` | `#FF0000` | `XM_STYLE_FOREGROUND_COLOR` |
| `color: rgba(255,0,0,0.5)` | `#FF000080` | `XM_STYLE_FOREGROUND_COLOR` |
| `background-color: yellow` | `#FFFF00` | `XM_STYLE_BACKGROUND_COLOR` |
| `font-size: 16px` | `16` | `XM_STYLE_FONT_SIZE` |
| `font-size: 1.5em` | `24` | `XM_STYLE_FONT_SIZE`（假设基准 16px） |
| `font-size: 12pt` | `16` | `XM_STYLE_FONT_SIZE`（1pt ≈ 1.333px） |
| `font-weight: bold` | `bold` | `XM_STYLE_FONT_WEIGHT` |
| `font-weight: 700` | `bold` | `XM_STYLE_FONT_WEIGHT` |
| `font-weight: 400` | `normal` | `XM_STYLE_FONT_WEIGHT` |
| `font-style: italic` | `italic` | `XM_STYLE_FONT_STYLE` |
| `text-decoration: underline` | `underline` | `XM_STYLE_TEXT_DECORATION` |
| `text-decoration: line-through` | `line-through` | `XM_STYLE_TEXT_DECORATION` |
| `text-align: center` | `center` | `XM_STYLE_TEXT_ALIGN` |
| `line-height: 1.5` | `1.5` | `XM_STYLE_LINE_HEIGHT` |
| `letter-spacing: 2px` | `2` | `XM_STYLE_LETTER_SPACING` |
| `color: unknownvalue` | `unknownvalue` | `XM_STYLE_FOREGROUND_COLOR`（无法识别时原值透传） |

---

## 12. 子项目 B 路线图与依赖说明

### 12.1 为什么当前只做子项目 A

| 原因 | 说明 |
|------|------|
| **接口先行** | 核心 C API 是三端桥接的契约。API 不稳定时写桥接代码会反复返工 |
| **质量基线** | 核心引擎的解析正确性、自动纠错、性能指标必须先通过验证，否则三端渲染结果必然不一致 |
| **依赖关系** | 桥接层需要链接编译好的 `xmarkup_core` 静态库/动态库，构建配置依赖核心引擎的交付物 |
| **测试数据复用** | 核心引擎的测试用例（含 HTML → ParsedResult 的输入输出对）将直接作为三端桥接层的集成测试基准 |

### 12.2 子项目 B 启动条件

子项目 A 必须达到以下状态后，子项目 B 才能启动：

- [ ] C API (`xmarkup.h`) 冻结，不再有破坏性变更
- [ ] 所有标签解析规范（第 11 章）的测试用例 100% 通过
- [ ] 50KB HTML 解析性能测试 < 15ms 通过
- [ ] 恶意 HTML 输入零崩溃测试通过
- [ ] ASAN / Valgrind 内存检查无泄漏
- [ ] 核心静态库/动态库可成功编译（Release 模式）

### 12.3 三端桥接层规划概览

以下为子项目 B 的初步规划，**细节将在子项目 A 完成后另行设计**。

| 阶段 | 平台 | 技术方案 | 转化目标 | 预计工期 |
|------|------|---------|---------|---------|
| B-1 | iOS | Swift 6+ 直接调用 C API（Xcode 26+ C++ 互操作） | `NSAttributedString` | 1~2 周 |
| B-2 | Android | JNI 胶水层 + Kotlin 封装 | `SpannableStringBuilder` | 1~2 周 |
| B-3 | 鸿蒙 | N-API 胶水层 + ArkTS 封装 | ArkUI `StyledString` | 1~2 周 |
| B-4 | 集成验证 | 三端共享同一组 HTML 测试用例 | 像素级一致性验证 | 1 周 |

#### B-1: iOS 桥接层关键点

- 使用 Swift 6+ / Xcode 26+ 的 C++ 互操作能力，直接调用核心引擎 C API，无需 ObjC++ 中间层
- `NSAttributedString` 构建策略：遍历 `spans[]`，按 range 分段应用 `NSAttributedString.Key`
- `<video>` / `<img>` 等非文本元素需要使用 `NSTextAttachment` 在文本流中嵌入原生视图
- `<table>` 渲染可能需要自定义 `NSTextLayoutSection` 或回退到 `UICollectionView`

#### B-2: Android 桥接层关键点

- JNI 层只做数据搬运（`XMResult` → Java 对象），避免在 JNI 中做业务逻辑
- Kotlin 封装层将 `XMSpan` 映射为 `CharacterStyle` 子类（`StyleSpan`、`ForegroundColorSpan` 等）
- `<video>` / `<img>` 需要使用 `ImageSpan` 或自定义 `ReplacementSpan`
- JNI 调用需注意：一次性拷贝全部 span 数据到 Java 侧，避免频繁跨语言调用

#### B-3: 鸿蒙桥接层关键点

- N-API 层将 `XMResult` 转为 ArkTS 的 `{ text: string, spans: Array<Span> }` 对象
- `StyledString` 通过 `TextStyle` 对象逐段应用样式
- 鸿蒙 N-API 与标准 Node-API **不完全兼容**，需按鸿蒙文档单独适配
- `<video>` / `<img>` 在 ArkUI 中可能需要将 `Text` 组件拆分为 `Text` + 原生组件的组合布局

#### B-4: 三端一致性验证

- 共享测试数据集：一组包含所有支持标签 + CSS 样式 + 乱序嵌套的 HTML 文件
- 对比三端渲染截图，验证字体、颜色、间距、列表符号等视觉元素一致
- 性能对比：三端解析相同 HTML 的耗时应在同一数量级

### 12.4 当前设计决策对桥接层的影响

以下当前设计决策直接影响桥接层的实现方式，此处说明**为什么这样设计**：

| 设计决策 | 对桥接层的影响 | 设计理由 |
|---------|--------------|---------|
| TextRange 使用 UTF-16 索引 | 三端可直接用原生字符串 API 切片，无需二次转换 | Swift `String.Index`、Java `String.charAt()`、ArkTS 字符串都是 UTF-16 |
| XMSpan 是扁平数组（非嵌套树） | 桥接层只需一个 `for` 循环遍历，O(N) 复杂度 | 嵌套树需要递归遍历，增加桥接层复杂度和出错可能 |
| 多对一标签映射（如 `<b>`/`<strong>` → `XM_TAG_BOLD`） | 桥接层只需处理一个 tag 类型，无需判断等价关系 | 减少桥接层的分支逻辑 |
| value 使用 `const char*` + `value_len` | JNI/N-API/Swift 都能直接读取 C 字符串指针 | 避免 C++ `std::string` 的跨语言 ABI 问题 |
| `<video>`/`<img>` 输出空区间 | 桥接层需特殊处理空区间，在该位置插入非文本组件 | 核心引擎不产生虚拟文本，避免影响纯文本的字符计数 |
| CSS 值标准化（颜色名→hex） | 桥接层直接解析 `#RRGGBB`，无需维护颜色名映射表 | 颜色名映射逻辑只需在核心层实现一次，三端复用 |
