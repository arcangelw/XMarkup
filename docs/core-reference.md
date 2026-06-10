# XMarkup 核心引擎参考文档

> 版本：0.1.0 | 更新：2026-06-09
> 适用对象：桥接层开发者（iOS / Android / 鸿蒙）及核心引擎贡献者

---

## 1. 快速开始

```c
#include "xmarkup/xmarkup.h"

// 最简用法（默认配置）
XMParser* parser = xmarkup_create(NULL);
XMResult* result = xmarkup_parse(parser, "<b>Hello</b>", 13);
printf("text: %.*s\n", result->text_len, result->text);  // → "Hello"
xmarkup_result_free(result);
xmarkup_destroy(parser);

// 完整配置
XMConfig cfg = {
    1,                // enable_autocorrect: 启用 Adoption Agency
    256,              // max_nesting_depth: 最大嵌套层数
    16.0f,            // base_font_size: 基准字号（px，浮点精度）
    my_log_callback,  // log_callback: 日志回调（NULL = 静默）
    &my_context,      // log_context: 回调用户数据
    XM_LOG_WARN       // log_level: 最低输出级别
};
XMParser* parser = xmarkup_create(&cfg);
```

---

## 2. C API 参考

### 2.1 生命周期

| 函数 | 说明 |
|------|------|
| `xmarkup_create(const XMConfig* config)` | 创建解析器。`config` 传 `NULL` 使用默认值。失败返回 `NULL`。 |
| `xmarkup_destroy(XMParser* parser)` | 销毁解析器。`NULL` 安全。销毁前须先 `xmarkup_result_free` 所有未释放的结果。 |
| `xmarkup_parse(XMParser* parser, const char* html, size_t length)` | 解析 HTML。返回 `XMResult*`，失败返回 `NULL`。结果在下一次 `parse` 前有效。 |
| `xmarkup_result_free(XMResult* result)` | 释放解析结果。`NULL` 安全。 |
| `xmarkup_last_error(XMParser* parser)` | 获取最近一次解析的错误码。 |
| `xmarkup_error_string(XMError error)` | 错误码转可读字符串（静态指针，无需释放）。 |
| `xmarkup_version(void)` | 返回版本号字符串 `"MAJOR.MINOR.PATCH"`。 |

### 2.2 错误码

| 枚举 | 值 | 说明 |
|------|-----|------|
| `XM_OK` | 0 | 成功 |
| `XM_ERR_NULL_PARSER` | -1 | `parser` 为 `NULL` |
| `XM_ERR_NULL_INPUT` | -2 | `html` 为 `NULL` 且 `length > 0` |
| `XM_ERR_NESTING_OVERFLOW` | -3 | 嵌套深度超限，已截断 |
| `XM_ERR_ALLOC_FAILED` | -4 | 内存分配失败 |

---

## 3. 数据类型

### 3.1 XMConfig — 解析器配置

```c
typedef struct XMConfig {
    uint8_t       enable_autocorrect;  // 是否启用 Adoption Agency（默认 1）
    uint16_t      max_nesting_depth;   // 最大嵌套深度（默认 256）
    float         base_font_size;      // 基准字号 px（默认 16.0f，浮点精度）
    XMLogCallback log_callback;        // 日志回调（默认 NULL = 静默）
    void*         log_context;         // 回调用户上下文（默认 NULL）
    XMLogLevel    log_level;           // 最低日志级别（默认 XM_LOG_ERROR）
} XMConfig;
```

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `enable_autocorrect` | `uint8_t` | `1` | 控制 Adoption Agency Algorithm。隐式关闭规则始终生效，不受此开关影响。 |
| `max_nesting_depth` | `uint16_t` | `256` | 超出后截断，防恶意输入栈溢出。 |
| `base_font_size` | `float` | `16.0f` | CSS 单位换算基准：`1em = 1rem = base_font_size px`，`1pt ≈ 1.333px`。 |
| `log_callback` | `XMLogCallback` | `NULL` | `NULL` 时所有日志方法为空操作，零性能开销。 |
| `log_context` | `void*` | `NULL` | 透传给 `log_callback`，库本身不使用。 |
| `log_level` | `XMLogLevel` | `XM_LOG_ERROR` | 只有级别 ≤ 此值的日志才会通过回调输出。 |

### 3.2 XMResult — 解析结果

```c
typedef struct XMResult {
    XMError       error;       // 错误码
    const char*   text;        // 纯文本（UTF-8，\0 结尾，保证非 NULL）
    uint32_t      text_len;    // text 字节长度
    const XMSpan* spans;       // 样式区间数组（UTF-16 索引）
    uint32_t      span_count;  // spans 数组长度
} XMResult;
```

`text` 是所有 HTML 标签移除、实体解码后的纯文本。`spans` 使用 **UTF-16 码元索引**（非 UTF-8 字节偏移），适配 Java `String`、Swift `NSString`、ArkTS `string`。

### 3.3 XMSpan — 样式区间

```c
typedef struct XMSpan {
    XMRange     range;       // [start, end) UTF-16 码元索引
    XMTagType   tag;         // HTML 标签类型（0 = 无标签）
    XMStyleType style;       // CSS 样式类型（0 = 无样式）
    const char* value;       // 属性值（href/src/颜色等），可为 NULL
    uint32_t    value_len;   // value 字节长度
} XMSpan;
```

解读规则：
- `tag != 0 && style == 0` → 标签语义 span（加粗、斜体、链接等）
- `tag == 0 && style != 0` → CSS 样式 span（颜色、字号等）
- `tag != 0 && style != 0` → 不会出现，标签和样式是独立 span
- `value` 含义：`<a>` → href，`<img>` → src，CSS color → `#RRGGBB`，font-size → px 数字字符串

### 3.4 XMRange — 文本区间

```c
typedef struct XMRange {
    uint32_t start;  // 起始（含），UTF-16 码元索引
    uint32_t end;    // 结束（不含），UTF-16 码元索引
} XMRange;
```

UTF-16 码元计数：ASCII/中文 1 码元，Emoji 2 码元（surrogate pair）。

### 3.5 XMLogLevel — 日志级别

```c
typedef enum XMLogLevel {
    XM_LOG_ERROR = 0,  // 不可恢复错误（内存分配失败等）
    XM_LOG_WARN  = 1,  // 容错决策（隐式关闭、adoption 等）
    XM_LOG_INFO  = 2,  // 关键节点（解析开始/结束）
    XM_LOG_TRACE = 3,  // 详细步骤（状态转换、CSS 标准化）
} XMLogLevel;
```

### 3.6 XMLogCallback — 日志回调

```c
typedef void (*XMLogCallback)(XMLogLevel level, const char* message, void* context);
```

---

## 4. 枚举参考

### 4.1 XMTagType — 标签类型

| 分组 | 枚举 | 值 | HTML 标签 | 备注 |
|------|------|----|-----------|------|
| **文本样式** | `XM_TAG_BOLD` | 1 | `<b>`, `<strong>` | 多对一映射 |
| | `XM_TAG_ITALIC` | 2 | `<i>`, `<em>` | |
| | `XM_TAG_UNDERLINE` | 3 | `<u>` | |
| | `XM_TAG_STRIKETHROUGH` | 4 | `<s>`, `<strike>`, `<del>` | |
| | `XM_TAG_SUBSCRIPT` | 5 | `<sub>` | |
| | `XM_TAG_SUPERSCRIPT` | 6 | `<sup>` | |
| | `XM_TAG_MARK` | 7 | `<mark>` | |
| | `XM_TAG_CODE` | 8 | `<code>` | |
| **段落结构** | `XM_TAG_PARAGRAPH` | 20 | `<p>` | |
| | `XM_TAG_HEADING_1`~`6` | 21~26 | `<h1>`~`<h6>` | |
| | `XM_TAG_BLOCKQUOTE` | 27 | `<blockquote>` | |
| | `XM_TAG_PREFORMATTED` | 28 | `<pre>` | 空白保留 |
| **链接与媒体** | `XM_TAG_LINK` | 40 | `<a>` | value = href |
| | `XM_TAG_IMAGE` | 41 | `<img>` | value = src，不产生文本 |
| | `XM_TAG_VIDEO` | 42 | `<video>` | 不产生文本 |
| | `XM_TAG_VIDEO_SOURCE` | 43 | `<source>`（video 内） | value = src |
| | `XM_TAG_AUDIO` | 44 | `<audio>` | 不产生文本 |
| | `XM_TAG_AUDIO_SOURCE` | 45 | `<source>`（audio 内） | value = src |
| **列表** | `XM_TAG_LIST_ORDERED` | 50 | `<ol>` | |
| | `XM_TAG_LIST_UNORDERED` | 51 | `<ul>` | |
| | `XM_TAG_LIST_ITEM` | 52 | `<li>` | |
| **表格** | `XM_TAG_TABLE` | 60 | `<table>` | |
| | `XM_TAG_TABLE_ROW` | 61 | `<tr>` | |
| | `XM_TAG_TABLE_CELL` | 62 | `<td>` | |
| | `XM_TAG_TABLE_HEADER` | 63 | `<th>` | |
| **其他** | `XM_TAG_HORIZONTAL_RULE` | 70 | `<hr>` | 不产生文本 |
| | `XM_TAG_LINE_BREAK` | 71 | `<br>` | 不产生文本 |
| | `XM_TAG_DIVISION` | 72 | `<div>` | |
| | `XM_TAG_SPAN` | 73 | `<span>` | |
| **语义块级容器** | `XM_TAG_ARTICLE` | 74 | `<article>` | |
| | `XM_TAG_SECTION` | 75 | `<section>` | |
| | `XM_TAG_HEADER` | 76 | `<header>` | |
| | `XM_TAG_FOOTER` | 77 | `<footer>` | |
| | `XM_TAG_NAV` | 78 | `<nav>` | |
| | `XM_TAG_ASIDE` | 79 | `<aside>` | |
| | `XM_TAG_FIGURE` | 80 | `<figure>` | |
| | `XM_TAG_FIGCAPTION` | 81 | `<figcaption>` | |
| | `XM_TAG_MAIN` | 82 | `<main>` | |
| | `XM_TAG_ADDRESS` | 83 | `<address>` | |
| | `XM_TAG_DL` | 84 | `<dl>` | |
| | `XM_TAG_DT` | 85 | `<dt>` | |
| | `XM_TAG_DD` | 86 | `<dd>` | |

跳过标签（不产生 span）：`<script>`, `<style>`, `<noscript>`, `<!-- -->`

未知标签：文本保留，不产生 span。

### 4.2 XMStyleType — CSS 样式属性

| 枚举 | 值 | CSS 属性 | 值格式 |
|------|-----|----------|--------|
| `XM_STYLE_FOREGROUND_COLOR` | 1 | `color` | `#RRGGBB` |
| `XM_STYLE_BACKGROUND_COLOR` | 2 | `background-color` | `#RRGGBB` |
| `XM_STYLE_FONT_SIZE` | 3 | `font-size` | px 数字字符串，如 `"24"` 或 `"21.75"` |
| `XM_STYLE_FONT_WEIGHT` | 4 | `font-weight` | `"bold"`, `"100"`~`"900"` |
| `XM_STYLE_FONT_STYLE` | 5 | `font-style` | `"italic"`, `"normal"` |
| `XM_STYLE_TEXT_DECORATION` | 6 | `text-decoration` | `"underline"`, `"line-through"` |
| `XM_STYLE_LINE_HEIGHT` | 7 | `line-height` | 原样输出 |
| `XM_STYLE_TEXT_ALIGN` | 8 | `text-align` | `"left"`, `"center"`, `"right"` |
| `XM_STYLE_LETTER_SPACING` | 9 | `letter-spacing` | px 数字字符串（同 font-size 单位换算） |
| `XM_STYLE_MEDIA_TYPE` | 10 | `<source>` 的 `type` | MIME 类型，如 `"video/mp4"` |
| `XM_STYLE_MEDIA_QUERY` | 11 | `<source>` 的 `media` | 媒体查询条件 |

### CSS 值标准化规则

**颜色：** 命名颜色 / `#RGB` / `#RRGGBB` / `rgb(r,g,b)` → 统一输出 `#RRGGBB`（大写）

**字号：** 输出最多保留 2 位小数的 px 数字字符串，无小数部分时省略。

| 输入 | 换算（base=16.0f） | 输出 |
|------|-------------------|------|
| `16px` | 原值 | `"16"` |
| `1.5em` | × base | `"24"` |
| `1.5rem` | × base | `"24"` |
| `12pt` | × 1.333 | `"16"` |
| `150%` | × base / 100 | `"24"` |
| `1.5`（无单位） | 原值 | `"1.5"` |
| `1.5em`（base=14.5） | × 14.5 | `"21.75"` |

---

## 5. 处理管线

```
HTML 字符串 (UTF-8)
       │
       ▼
┌──────────────┐
│  Tokenizer   │  手写状态机，标签名小写化
│              │  Token.tag_name 为 owned std::string
│              │  跳过 script/style/noscript/comment
└──────┬───────┘
       │ Token[]
       ▼
┌──────────────┐
│ TreeBuilder  │  栈式构建 + 隐式关闭 6 规则
│              │  + Adoption Agency（enable_autocorrect 控制）
│              │  + Scope Boundary 防跨容器
│              │  深度限制 max_nesting_depth
└──────┬───────┘
       │ ASTNode（tag_name 为 owned std::string）
       ▼
┌──────────────┐
│StyleResolver │  DFS 遍历：标签映射 + CSS 解析
│+ EntityDecoder│ HTML 实体解码 + 空白折叠
│              │ 父标签栈（source 上下文感知）
│              │ 块级元素换行分隔
└──────┬───────┘
       │ FlattenResult{text, spans[byte_offset]}
       ▼
┌──────────────┐
│ UTF16Indexer │  byte offset → UTF-16 索引
│              │  单趟扫描 + 二分查找
└──────┬───────┘
       │
       ▼
   XMResult{text(UTF-8), spans[](UTF-16)}
```

---

## 6. 模块详解

### 6.1 Tokenizer — 词法分析

**文件：** `core/src/tokenizer.h`, `core/src/tokenizer.cpp`

| 项目 | 说明 |
|------|------|
| 状态机 | 手写有限状态机，约 12 个状态 |
| 输入 | `std::string_view`（零拷贝引用原始 HTML） |
| 输出 | `Token{type, raw, tag_name, attributes}` |
| tag_name | `std::string`（owned，已小写化），不再指向原始输入 |
| raw / attributes | `std::string_view`，指向原始 HTML |
| 跳过 | `<script>` / `<style>` / `<noscript>` 整体跳过，`<!-- -->` 静默跳过 |
| 标签名大小写 | `<DIV>`, `<Div>` → `tag_name = "div"` |

### 6.2 TreeBuilder — AST 构建

**文件：** `core/src/tree_builder.h`, `core/src/tree_builder.cpp`

ASTNode 结构：

| 字段 | 类型 | 说明 |
|------|------|------|
| `type` | `ROOT / ELEMENT / TEXT` | 节点类型 |
| `tag_name` | `std::string` | 标签名（小写化，owned），仅 ELEMENT 有效 |
| `attributes` | `std::string_view` | 属性字符串，指向原始 Token 数据 |
| `text` | `std::string_view` | 文本内容，仅 TEXT 有效 |
| `children` | `std::vector<ASTNode>` | 子节点列表 |

核心能力：

| 能力 | 说明 | 开关 |
|------|------|------|
| Void 元素 | `<br>`, `<img>` 等 14 个元素不入栈 | 始终生效 |
| 未闭合补齐 | 文档末尾栈中剩余节点自动保留 | 始终生效 |
| 多余闭合忽略 | 无匹配的 `</tag>` 静默忽略 | 始终生效 |
| 深度限制 | 超过 `max_nesting_depth` 截断 | 始终生效 |
| **隐式关闭 6 规则** | `<p>`, `<li>`, `<dt>/<dd>`, `<tr>`, `<td>/<th>`, `<h1>`-`<h6>` | **始终生效** |
| **Scope Boundary** | div/blockquote/table 等阻止跨容器扫描 | 始终生效 |
| **Adoption Agency** | 行内标签跨块级元素时自动重建 | `enable_autocorrect` 控制 |
| Adoption 深度限制 | `kMaxAdoptionDepth = 32`，超出截断 | 始终生效 |
| Adoption 语义跳过 | span/sub/sup 不参与重建 | 始终生效 |

**隐式关闭 6 条规则（HTML5 规范合规）：**

| 规则 | 标签 | 触发条件 |
|------|------|---------|
| 1 | `<p>` | 遇任何块级元素（含自身） |
| 2 | `<li>` | 遇 `<li>` |
| 3 | `<dt>` / `<dd>` | 互相关闭 |
| 4 | `<tr>` | 遇 `<tr>` |
| 5 | `<td>` / `<th>` | 遇 `<td>` / `<th>` / `<tr>` |
| 6 | `<h1>`-`<h6>` | 遇块级元素 |

**Scope Boundary 标签：** `div`, `blockquote`, `pre`, `table`, `ul`, `ol`, `video`, `audio`, `article`, `section`, `header`, `footer`, `main`, `nav`, `aside`

**Adoption Agency Algorithm：** 当 `enable_autocorrect = true` 时，遇到块级开始标签会检查栈顶是否有连续的行内格式化标签（b/strong/i/em/u/s/del/a/code/mark），如有则弹出并重建到新块级元素内部。

### 6.3 StyleResolver — 样式解析

**文件：** `core/src/style_resolver.h`, `core/src/style_resolver.cpp`

DFS 遍历 AST，同时完成 7 项工作：

1. **HTML 实体解码**：`&amp;` → `&`，`&#60;` → `<`，`&#x4e2d;` → `中`
2. **空白折叠**：非 `<pre>` 内连续空白折叠为单个空格；`<pre>` 内原样保留
3. **标签映射**：通过 `tag_map()` 查表，多对一映射（`<b>` + `<strong>` → `XM_TAG_BOLD`）
4. **属性提取**：`<a>` 的 href，`<img>` 的 src
5. **`<source>` 上下文感知**：父标签栈判定 `<source>` 在 `<video>` 还是 `<audio>` 内
6. **CSS 行内样式解析**：`style` 属性中的 color/font-size 等
7. **块级元素换行**：块级元素前后插入 `\n`，避免堆叠空行

Span 顺序：outside-in（`<b><i>text</i></b>` → `[BOLD, ITALIC]`）

### 6.4 EntityDecoder — 实体解码

**文件：** `core/src/entity_decoder.h`, `core/src/entity_decoder.cpp`

| 类型 | 格式 | 示例 | 解码 |
|------|------|------|------|
| 命名实体 | `&name;` | `&amp;` | `&` |
| 十进制 | `&#NNN;` | `&#60;` | `<` |
| 十六进制 | `&#xHHH;` | `&#x4e2d;` | `中` |

容错：不完整实体保留原文，非法数字实体保留原文。

### 6.5 UTF16Indexer — 索引映射

**文件：** `core/src/utf16_indexer.h`, `core/src/utf16_indexer.cpp`

单趟扫描 UTF-8 文本，在序列长度变化处记录锚点。查询时 `std::lower_bound` 二分查找。

| UTF-8 长度 | UTF-16 码元 | 示例 |
|-----------|------------|------|
| 1 字节 (ASCII) | 1 | `A` |
| 2 字节 | 1 | `é` |
| 3 字节 | 1 | `中` |
| 4 字节 | 2 (surrogate pair) | `😊` |

### 6.6 Logger — 日志系统

**文件：** `core/src/logger.h`, `core/src/logger.cpp`

静态类，通过 `XMConfig.log_callback` 输出日志。

| 级别 | 用途 | 插桩位置 |
|------|------|---------|
| `ERROR` | 不可恢复错误 | parser.cpp（内存分配失败） |
| `WARN` | 容错决策 | tree_builder.cpp（隐式关闭、adoption、未闭合/多余闭合标签） |
| `INFO` | 关键节点 | parser.cpp（解析开始/结束） |
| `TRACE` | 详细步骤 | tokenizer.cpp（标签小写化、注释/rawtext 跳过），style_resolver.cpp（标签映射、字号标准化） |

性能保证：`log_callback` 为 `NULL` 时，所有方法仅做一次指针判空后立即返回，零开销。

### 6.7 Parser + API — 管线编排与 C 接口

**文件：** `core/src/parser.h`, `core/src/parser.cpp`, `core/src/api.cpp`

`ParserInternal` 串联 5 个阶段：Tokenizer → TreeBuilder → StyleResolver → UTF16Indexer → 组装 XMResult。

`api.cpp` 是 `extern "C"` 薄封装，将 `ParserInternal` 暴露为不透明 `XMParser*` 句柄。

---

## 7. 内存与线程

### 7.1 内存管理规则

```
xmarkup_create()    → 分配 ParserInternal
    ↓
xmarkup_parse()     → 分配 XMResult（内部指针指向 ParserInternal 的 owned_* 成员）
    ↓
xmarkup_result_free() → 仅释放 XMResult 结构体
    ↓
xmarkup_destroy()   → 释放 ParserInternal 及所有 owned_* 数据
```

关键规则：
- 每个 `XMResult*` 必须在 `xmarkup_destroy` 之前释放
- `XMResult` 中 `text`/`spans`/`value` 在下次 `parse` 或 `result_free` 后失效
- `xmarkup_result_free(NULL)` 和 `xmarkup_destroy(NULL)` 均安全

### 7.2 线程安全

- **不同 `XMParser*` 实例**：完全线程安全，可跨线程并行解析
- **同一 `XMParser*` 实例**：不可并发使用，每线程应创建独立实例
- `xmarkup_error_string()` / `xmarkup_version()`：纯函数，线程安全
- Logger：全局静态，通过 `xmarkup_create` 设置，需确保回调线程安全

---

## 8. 性能

### 8.1 基线数据（Release 模式，Apple M 系列，参考值）

| 输入大小 | 耗时 | 吞吐量 |
|---------|------|--------|
| 50 KB | ~4 ms | ~12 MB/s |
| 100 KB | ~8 ms | ~12 MB/s |
| 1 MB | ~80 ms | ~12 MB/s |

线性缩放，无超线性增长。

### 8.2 性能回归测试（CI 集成）

| 测试名 | 阈值 | 目的 |
|--------|------|------|
| `PerfRegression_50KB_Under15ms` | 50KB < 30ms（含 ASAN 开销） | 核心基线 |
| `PerfRegression_100KB_ScaleLinear` | 100KB < 50KB × 3.5 | 线性缩放 |
| `PerfRegression_DeepNesting_NoExplosion` | 1000 层 < 5ms | 深度限制性能 |
| `Stress50KB` | 50KB < 50ms | 宽松烟雾测试 |

### 8.3 Benchmark 工具

```bash
# 构建（默认 OFF，需手动开启）
cmake -B build-bench -DXMARKUP_BUILD_BENCHMARKS=ON
cmake --build build-bench

# 运行 23 个 benchmark case
./build-bench/tests/xmarkup_bench
```

23 个 case 覆盖：吞吐量（6）+ 分阶段耗时（4）+ 内存（3）+ 并发（2）+ 特殊场景（3）+ 新增（5：小输入延迟/纯文本/纯实体/heavy-tags/adoption 10000）

---

## 9. 测试

### 9.1 测试矩阵

| 模块 | 测试文件 | 测试数 | 覆盖范围 |
|------|----------|--------|----------|
| Tokenizer | `test_tokenizer.cpp` | 31 | 文本、标签、属性（布尔/空/引号）、大小写、注释、script/style/textarea/title 跳过、非法输入、`
<<`/`/` 容错 |
| TreeBuilder | `test_tree_builder.cpp` | 25 | 嵌套、void 元素、隐式关闭 6 规则、Scope Boundary、Adoption Agency（基本/多层/深度超限/span 保留/混合隐式关闭）、深度限制 |
| StyleResolver | `test_style_resolver.cpp` | 101 | 标签映射（含 sub/sup/code/mark/del）、CSS 全部 11 属性颜色/字号/背景/字体/文本/字间距换算、块级换行 18 类、source 上下文（含 type/media）、属性大小写不敏感、!important 剥离、rgba/hsl/hsla |
| EntityDecoder | `test_entity_decoder.cpp` | 13 | 命名/十进制/十六进制实体、容错、连续实体、尾部位 &、空数字体 |
| UTF16Indexer | `test_utf16_indexer.cpp` | 9 | ASCII、中文、Emoji、混合、空字符串、非法续字节、中间偏移量、多 4 字节序列 |
| API 集成 | `test_api.cpp` | 60 | 完整管线、h2-h6 全级/有序列表/sub/sup/code/mark/del 标签、CSS 全部 11 属性、autocorrect 禁用、语义块级标签 13 种、纠错、实体解码、CSS 标准化、性能回归、深度边界、恶意输入、线程安全、日志回调 |
| **合计** | | **239** | |

### 9.2 构建模式

```bash
# 日常开发
cmake -B build && cmake --build build && cd build && ctest

# ASAN + UBSan
cmake -B build-asan -DCMAKE_CXX_FLAGS="-fsanitize=address,undefined -fno-omit-frame-pointer" \
      -DCMAKE_EXE_LINKER_FLAGS="-fsanitize=address,undefined"
cmake --build build-asan && cd build-asan && ctest

# 性能 Benchmark
cmake -B build-bench -DXMARKUP_BUILD_BENCHMARKS=ON && cmake --build build-bench
./build-bench/tests/xmarkup_bench
```

---

## 10. 扩展指南

### 添加新标签

1. `xmarkup.h` → `XMTagType` 枚举添加新值
2. `style_resolver.cpp` → `tag_map()` 添加映射
3. 编写测试

### 添加新 CSS 属性

1. `xmarkup.h` → `XMStyleType` 枚举添加新值
2. `style_resolver.cpp` → `add_style_spans()` 添加属性名匹配和标准化
3. 编写测试

### 添加新 HTML 实体

1. `entity_decoder.cpp` → `named_entities()` 映射表添加条目
2. 编写测试

---

## 11. 文件索引

```
core/
├── include/xmarkup/
│   └── xmarkup.h              # 唯一公共头文件（C API）
├── src/
│   ├── tokenizer.h / .cpp     # 词法分析器（状态机）
│   ├── tree_builder.h / .cpp  # AST 构建器（隐式关闭 + Adoption Agency）
│   ├── style_resolver.h / .cpp # 样式解析器（标签映射 + CSS + 块级换行）
│   ├── entity_decoder.h / .cpp # HTML 实体解码器
│   ├── utf16_indexer.h / .cpp  # UTF-8 → UTF-16 索引映射
│   ├── logger.h / .cpp        # 日志系统（4 级别 + 回调）
│   ├── parser.h / .cpp        # 管线编排（ParserInternal）
│   └── api.cpp                # extern "C" API 薄封装
└── CMakeLists.txt             # 静态库 xmarkup_core

tests/
├── test_tokenizer.cpp         # 31 tests
├── test_tree_builder.cpp      # 25 tests
├── test_style_resolver.cpp    # 101 tests
├── test_entity_decoder.cpp    # 13 tests
├── test_utf16_indexer.cpp     # 9 tests
├── test_api.cpp               # 60 tests
├── bench_helpers.h            # Benchmark 辅助工具
├── benchmark.cpp              # 23 个 Google Benchmark case
└── CMakeLists.txt             # 测试 + 可选 Benchmark target
```
