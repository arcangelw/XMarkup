# XMarkup C API 参考文档

> 版本：0.1.0 | 头文件：`core/include/xmarkup/xmarkup.h`

本文档面向使用 XMarkup 核心引擎的桥接层开发者（iOS / Android / 鸿蒙）。

---

## 目录

- [快速参考](#快速参考)
- [生命周期管理](#生命周期管理)
- [核心解析](#核心解析)
- [错误处理](#错误处理)
- [枚举类型](#枚举类型)
- [结构体](#结构体)
- [内存管理规则](#内存管理规则)
- [线程安全](#线程安全)
- [标签映射表](#标签映射表)
- [CSS 样式映射表](#css-样式映射表)

---

## 快速参考

```c
#include "xmarkup/xmarkup.h"

/* 创建 → 解析 → 读取 → 释放 */
XMConfig cfg = {1, 256, 16};
XMParser* parser = xmarkup_create(&cfg);
XMResult* result = xmarkup_parse(parser, html, length);
/* 使用 result->text, result->spans ... */
xmarkup_result_free(result);
xmarkup_destroy(parser);
```

---

## 生命周期管理

### `xmarkup_create`

```c
XMParser* xmarkup_create(const XMConfig* config);
```

创建解析器实例。

**参数：**

| 参数 | 类型 | 说明 |
|------|------|------|
| `config` | `const XMConfig*` | 配置参数，传 `NULL` 使用默认值 `{1, 256, 16}` |

**返回值：** 成功返回解析器指针，失败（内存不足）返回 `NULL`。

**示例：**

```c
// 使用默认配置
XMParser* p = xmarkup_create(NULL);

// 自定义配置
XMConfig cfg;
cfg.enable_autocorrect = 1;    // 启用自动纠错
cfg.max_nesting_depth = 128;   // 最大嵌套深度
cfg.base_font_size = 14;      // 基准字号 14px
XMParser* p = xmarkup_create(&cfg);
```

---

### `xmarkup_destroy`

```c
void xmarkup_destroy(XMParser* parser);
```

销毁解析器实例，释放所有内部资源。

**参数：**

| 参数 | 类型 | 说明 |
|------|------|------|
| `parser` | `XMParser*` | 解析器指针，传 `NULL` 安全（无操作） |

**注意：** 销毁前必须先释放所有通过 `xmarkup_parse` 返回的 `XMResult*`。

---

## 核心解析

### `xmarkup_parse`

```c
XMResult* xmarkup_parse(XMParser* parser, const char* html, size_t length);
```

解析 HTML 字符串，返回解析结果。

**参数：**

| 参数 | 类型 | 说明 |
|------|------|------|
| `parser` | `XMParser*` | 解析器实例 |
| `html` | `const char*` | HTML 字符串（UTF-8 编码，不需要以 `\0` 结尾） |
| `length` | `size_t` | `html` 的字节长度 |

**返回值：**

| 情况 | 返回值 |
|------|--------|
| 解析成功 | `XMResult*`，其中 `result->error == XM_OK` |
| `parser` 为 `NULL` | `NULL` |
| `html` 为 `NULL` 且 `length > 0` | `NULL` |
| 内存分配失败 | `NULL` |

**重要：** 返回的 `XMResult*` 指针在下次调用 `xmarkup_parse` 之前有效。使用完毕后必须调用 `xmarkup_result_free` 释放。

**示例：**

```c
const char* html = "<b>Hello</b> <i>World</i>";
XMResult* r = xmarkup_parse(parser, html, strlen(html));

if (r && r->error == XM_OK) {
    printf("纯文本: %.*s\n", r->text_len, r->text);
    for (uint32_t i = 0; i < r->span_count; i++) {
        XMSpan* s = &r->spans[i];
        // s->range.start, s->range.end 是 UTF-16 索引
        // s->tag 是 XMTagType 枚举
        // s->style 是 XMStyleType 枚举（如果有 inline style）
        // s->value 是属性值字符串（如 href、src），可能为 NULL
    }
}
xmarkup_result_free(r);
```

---

### `xmarkup_result_free`

```c
void xmarkup_result_free(XMResult* result);
```

释放 `xmarkup_parse` 返回的解析结果。

**参数：**

| 参数 | 类型 | 说明 |
|------|------|------|
| `result` | `XMResult*` | 解析结果指针，传 `NULL` 安全（无操作） |

**注意：** 释放后，`result` 及其 `text`、`spans`、`spans[].value` 指针全部失效。

---

## 错误处理

### `xmarkup_last_error`

```c
XMError xmarkup_last_error(XMParser* parser);
```

获取解析器最近一次 `xmarkup_parse` 的错误码。

**参数：**

| 参数 | 类型 | 说明 |
|------|------|------|
| `parser` | `XMParser*` | 解析器实例，传 `NULL` 返回 `XM_ERR_NULL_PARSER` |

**返回值：** `XMError` 枚举值。

---

### `xmarkup_error_string`

```c
const char* xmarkup_error_string(XMError error);
```

将错误码转换为可读字符串。

**返回值：** 静态字符串指针，无需释放。

| 错误码 | 字符串 |
|--------|--------|
| `XM_OK` | `"Success"` |
| `XM_ERR_NULL_PARSER` | `"Parser is NULL"` |
| `XM_ERR_NULL_INPUT` | `"Input HTML is NULL"` |
| `XM_ERR_NESTING_OVERFLOW` | `"Nesting depth overflow, truncated"` |
| `XM_ERR_ALLOC_FAILED` | `"Memory allocation failed"` |

---

## 枚举类型

### `XMTagType` — 标签类型

标签类型分为 5 个分组，每组保留整数区间以便未来扩展。

#### 文本样式（1-9）

| 枚举值 | 值 | HTML 标签 |
|--------|-----|-----------|
| `XM_TAG_BOLD` | 1 | `<b>`, `<strong>` |
| `XM_TAG_ITALIC` | 2 | `<i>`, `<em>` |
| `XM_TAG_UNDERLINE` | 3 | `<u>` |
| `XM_TAG_STRIKETHROUGH` | 4 | `<s>`, `<strike>`, `<del>` |
| `XM_TAG_SUBSCRIPT` | 5 | `<sub>` |
| `XM_TAG_SUPERSCRIPT` | 6 | `<sup>` |
| `XM_TAG_MARK` | 7 | `<mark>` |
| `XM_TAG_CODE` | 8 | `<code>` |

#### 段落结构（20-29）

| 枚举值 | 值 | HTML 标签 |
|--------|-----|-----------|
| `XM_TAG_PARAGRAPH` | 20 | `<p>` |
| `XM_TAG_HEADING_1` | 21 | `<h1>` |
| `XM_TAG_HEADING_2` | 22 | `<h2>` |
| `XM_TAG_HEADING_3` | 23 | `<h3>` |
| `XM_TAG_HEADING_4` | 24 | `<h4>` |
| `XM_TAG_HEADING_5` | 25 | `<h5>` |
| `XM_TAG_HEADING_6` | 26 | `<h6>` |
| `XM_TAG_BLOCKQUOTE` | 27 | `<blockquote>` |
| `XM_TAG_PREFORMATTED` | 28 | `<pre>` |

#### 链接与媒体（40-49）

| 枚举值 | 值 | HTML 标签 | 说明 |
|--------|-----|-----------|------|
| `XM_TAG_LINK` | 40 | `<a>` | `value` 字段存储 `href` 属性值 |
| `XM_TAG_IMAGE` | 41 | `<img>` | `value` 字段存储 `src` 属性值，不产生文本 |
| `XM_TAG_VIDEO` | 42 | `<video>` | 不产生文本 |
| `XM_TAG_VIDEO_SOURCE` | 43 | `<source>`（在 `<video>` 内） | `value` 字段存储 `src`，由父标签栈自动判定上下文 |
| `XM_TAG_AUDIO` | 44 | `<audio>` | 不产生文本 |
| `XM_TAG_AUDIO_SOURCE` | 45 | `<source>`（在 `<audio>` 内） | `value` 字段存储 `src`，由父标签栈自动判定上下文 |

#### 列表（50-59）

| 枚举值 | 值 | HTML 标签 |
|--------|-----|-----------|
| `XM_TAG_LIST_ORDERED` | 50 | `<ol>` |
| `XM_TAG_LIST_UNORDERED` | 51 | `<ul>` |
| `XM_TAG_LIST_ITEM` | 52 | `<li>` |

#### 表格（60-69）

| 枚举值 | 值 | HTML 标签 |
|--------|-----|-----------|
| `XM_TAG_TABLE` | 60 | `<table>` |
| `XM_TAG_TABLE_ROW` | 61 | `<tr>` |
| `XM_TAG_TABLE_CELL` | 62 | `<td>` |
| `XM_TAG_TABLE_HEADER` | 63 | `<th>` |

#### 其他（70-79）

| 枚举值 | 值 | HTML 标签 | 说明 |
|--------|-----|-----------|------|
| `XM_TAG_HORIZONTAL_RULE` | 70 | `<hr>` | 不产生文本 |
| `XM_TAG_LINE_BREAK` | 71 | `<br>` | 不产生文本 |
| `XM_TAG_DIVISION` | 72 | `<div>` | |
| `XM_TAG_SPAN` | 73 | `<span>` | |

---

### `XMStyleType` — CSS 样式属性

| 枚举值 | 值 | 对应 CSS 属性 | 值格式 |
|--------|-----|--------------|--------|
| `XM_STYLE_FOREGROUND_COLOR` | 1 | `color` | `#RRGGBB` |
| `XM_STYLE_BACKGROUND_COLOR` | 2 | `background-color` | `#RRGGBB` |
| `XM_STYLE_FONT_SIZE` | 3 | `font-size` | 纯数字字符串（px），如 `"24"` |
| `XM_STYLE_FONT_WEIGHT` | 4 | `font-weight` | `"bold"`, `"100"`~`"900"` |
| `XM_STYLE_FONT_STYLE` | 5 | `font-style` | `"italic"`, `"normal"` |
| `XM_STYLE_TEXT_DECORATION` | 6 | `text-decoration` | `"underline"`, `"line-through"` |
| `XM_STYLE_LINE_HEIGHT` | 7 | `line-height` | 原样输出 |
| `XM_STYLE_TEXT_ALIGN` | 8 | `text-align` | `"left"`, `"center"`, `"right"` |
| `XM_STYLE_LETTER_SPACING` | 9 | `letter-spacing` | 原样输出 |

---

### `XMError` — 错误码

| 枚举值 | 值 | 说明 |
|--------|-----|------|
| `XM_OK` | 0 | 成功 |
| `XM_ERR_NULL_PARSER` | -1 | 传入的 `parser` 指针为 `NULL` |
| `XM_ERR_NULL_INPUT` | -2 | `html` 为 `NULL` 但 `length > 0` |
| `XM_ERR_NESTING_OVERFLOW` | -3 | 嵌套深度超出 `max_nesting_depth`，已截断 |
| `XM_ERR_ALLOC_FAILED` | -4 | 内存分配失败 |

---

## 结构体

### `XMConfig` — 配置

```c
typedef struct XMConfig {
    uint8_t  enable_autocorrect;   // 是否启用自动纠错（默认 1）
    uint16_t max_nesting_depth;    // 最大嵌套深度（默认 256）
    uint16_t base_font_size;       // 基准字号，单位 px（默认 16）
} XMConfig;
```

**字段说明：**

- `enable_autocorrect`：设为 `1` 时，乱序嵌套（如 `<a><b></a></b>`）和未闭合标签会自动修复；设为 `0` 时严格模式。
- `max_nesting_depth`：超过此深度的标签会被截断，防止恶意 HTML 导致栈溢出。
- `base_font_size`：用于 CSS 单位换算——`1em = base_font_size px`，`1rem = base_font_size px`，`1pt ≈ 1.333px`，百分比 `N% = N * base_font_size / 100 px`。

---

### `XMResult` — 解析结果

```c
typedef struct XMResult {
    XMError       error;       // 错误码
    const char*   text;        // 纯文本（UTF-8，以 \0 结尾）
    uint32_t      text_len;    // text 的字节长度
    const XMSpan* spans;       // 样式区间数组
    uint32_t      span_count;  // spans 数组长度
} XMResult;
```

**字段说明：**

- `text`：所有 HTML 标签被移除、实体被解码后的纯文本。UTF-8 编码，保证非 `NULL`（空输入时为空字符串 `""`）。
- `spans`：样式区间数组，每个元素描述一个标签或 CSS 属性在文本中的位置。`range.start` 和 `range.end` 使用 **UTF-16 码元索引**。
- `span_count`：可以为 0（纯文本无样式）。

---

### `XMSpan` — 样式区间

```c
typedef struct XMSpan {
    XMRange     range;       // UTF-16 索引区间 [start, end)
    XMTagType   tag;         // 标签类型（如 XM_TAG_BOLD）
    XMStyleType style;       // CSS 样式类型（0 表示无样式，由标签语义决定）
    const char* value;       // 属性值字符串，可能为 NULL
    uint32_t    value_len;   // value 的字节长度
} XMSpan;
```

**解读规则：**

- 当 `tag != 0 && style == 0`：这是一个**标签语义 span**（如加粗、斜体、链接）。
- 当 `tag == 0 && style != 0`：这是一个 **CSS 样式 span**（如颜色、字号），与对应的标签 span 共享相同的 `range`。
- 当 `tag != 0 && style != 0`：不会出现（标签和样式是独立的 span）。
- `value`：对于 `<a>` 是 `href` 值，对于 `<img>` 是 `src` 值，对于 CSS `color` 是 `#RRGGBB` 值。

---

### `XMRange` — 文本区间

```c
typedef struct XMRange {
    uint32_t start;  // 起始位置（UTF-16 码元索引，含）
    uint32_t end;    // 结束位置（UTF-16 码元索引，不含）
} XMRange;
```

半开区间 `[start, end)`。注意是 UTF-16 码元索引，不是 UTF-8 字节偏移。

- ASCII 字符：1 字符 = 1 UTF-16 码元，索引等于字符位置
- 中文等多字节字符：1 字符 = 1 UTF-16 码元
- Emoji 等 4 字节 UTF-8 字符：1 字符 = 2 UTF-16 码元（surrogate pair）

---

## 内存管理规则

```
xmarkup_create()  →  分配 XMParser
    ↓
xmarkup_parse()   →  分配 XMResult（内部持有 text/spans/value 的内存）
    ↓                     ↓
xmarkup_parse()   →  上一次的 XMResult 仍然有效
    ↓                     ↓
xmarkup_result_free() →  释放 XMResult
    ↓
xmarkup_destroy() →  释放 XMParser 及其所有内部数据
```

**关键规则：**

1. 一个 `XMParser*` 可以反复调用 `xmarkup_parse`，每次返回独立的 `XMResult*`。
2. 每个 `XMResult*` 必须在 `xmarkup_destroy` 之前调用 `xmarkup_result_free` 释放。
3. `XMResult` 中的 `text`、`spans`、`spans[].value` 指针在 `xmarkup_result_free` 后失效。
4. `xmarkup_result_free(NULL)` 和 `xmarkup_destroy(NULL)` 均安全（无操作）。

---

## 线程安全

- **不同 `XMParser*` 实例之间完全线程安全**——可以在不同线程中创建独立的解析器并行解析。
- **同一 `XMParser*` 实例不可跨线程并发使用**——如需并发，每个线程创建独立的 `XMParser*`。
- `xmarkup_error_string()` 是纯函数，线程安全。

**推荐用法（Android JNI 示例）：**

```c
// 每个线程创建独立解析器
XMParser* parser = xmarkup_create(&shared_config);
XMResult* result = xmarkup_parse(parser, html, length);
// ... 处理 result ...
xmarkup_result_free(result);
xmarkup_destroy(parser);
```

---

## 标签映射表

| HTML 标签 | XMTagType | 产生文本 | 属性值 |
|-----------|-----------|----------|--------|
| `<b>`, `<strong>` | `XM_TAG_BOLD` | 是 | — |
| `<i>`, `<em>` | `XM_TAG_ITALIC` | 是 | — |
| `<u>` | `XM_TAG_UNDERLINE` | 是 | — |
| `<s>`, `<strike>`, `<del>` | `XM_TAG_STRIKETHROUGH` | 是 | — |
| `<sub>` | `XM_TAG_SUBSCRIPT` | 是 | — |
| `<sup>` | `XM_TAG_SUPERSCRIPT` | 是 | — |
| `<mark>` | `XM_TAG_MARK` | 是 | — |
| `<code>` | `XM_TAG_CODE` | 是 | — |
| `<p>` | `XM_TAG_PARAGRAPH` | 是 | — |
| `<h1>`~`<h6>` | `XM_TAG_HEADING_1`~`6` | 是 | — |
| `<blockquote>` | `XM_TAG_BLOCKQUOTE` | 是 | — |
| `<pre>` | `XM_TAG_PREFORMATTED` | 是（空白保留） | — |
| `<a>` | `XM_TAG_LINK` | 是 | `value` = `href` |
| `<img>` | `XM_TAG_IMAGE` | 否 | `value` = `src` |
| `<video>` | `XM_TAG_VIDEO` | 否 | — |
| `<source>`（video 内） | `XM_TAG_VIDEO_SOURCE` | 否 | `value` = `src` |
| `<source>`（audio 内） | `XM_TAG_AUDIO_SOURCE` | 否 | `value` = `src` |
| `<audio>` | `XM_TAG_AUDIO` | 否 | — |
| `<ul>` | `XM_TAG_LIST_UNORDERED` | 是 | — |
| `<ol>` | `XM_TAG_LIST_ORDERED` | 是 | — |
| `<li>` | `XM_TAG_LIST_ITEM` | 是 | — |
| `<table>` | `XM_TAG_TABLE` | 是 | — |
| `<tr>` | `XM_TAG_TABLE_ROW` | 是 | — |
| `<td>` | `XM_TAG_TABLE_CELL` | 是 | — |
| `<th>` | `XM_TAG_TABLE_HEADER` | 是 | — |
| `<hr>` | `XM_TAG_HORIZONTAL_RULE` | 否 | — |
| `<br>` | `XM_TAG_LINE_BREAK` | 否 | — |
| `<div>` | `XM_TAG_DIVISION` | 是 | — |
| `<span>` | `XM_TAG_SPAN` | 是 | — |
| `<script>`, `<style>`, `<noscript>` | — | 跳过 | 整体跳过 |
| `<!-- -->` | — | 跳过 | 静默跳过 |
| 未知标签 | — | 是 | 不产生 span |

---

## CSS 样式映射表

### 颜色标准化

| 输入格式 | 输出 | 示例 |
|----------|------|------|
| 命名颜色 | `#RRGGBB` | `red` → `#FF0000` |
| `#RGB` | `#RRGGBB` | `#f00` → `#FF0000` |
| `#RRGGBB` | `#RRGGBB`（大写） | `#ff0000` → `#FF0000` |
| `rgb(r,g,b)` | `#RRGGBB` | `rgb(255,0,0)` → `#FF0000` |

### 字号单位换算

| 输入单位 | 换算公式 | 示例（base=16） |
|----------|----------|----------------|
| `px` | 原值 | `16px` → `"16"` |
| `em` | × base_font_size | `1.5em` → `"24"` |
| `rem` | × base_font_size | `1.5rem` → `"24"` |
| `pt` | × 1.333 | `12pt` → `"16"` |
| `%` | × base / 100 | `150%` → `"24"` |
| 无单位 | 原值 | `2` → `"2"` |

输出均为四舍五入的整数 px 值字符串。
