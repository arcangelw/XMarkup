# XMarkup C++ 核心引擎架构文档

> 版本：0.1.0 | 更新：2026-06-10
> 本文档描述核心引擎的架构设计、模块职责和关键决策。
> 面向核心引擎贡献者和桥接层开发者。

---

## 1. 概述

XMarkup 核心引擎是一个**从零手写**的 C++17 HTML 富文本解析库，将 HTML 片段解析为纯文本 + 样式区间（spans）。输出结构可直接驱动三方平台（iOS/macOS/Android/Harmony）的原生富文本渲染。

### 核心数据流

```
HTML (UTF-8)  →  [四阶段管线]  →  XMResult{ text, spans[] }
```

输出 `XMResult` 包含：
- **纯文本**——去除标签、解码实体、空白折叠后的可见文本
- **样式区间**——扁平数组，每个 span 标记一段文本的标签类型和/或 CSS 样式

### 设计目标

| 维度 | 目标 |
|:--|:--|
| 性能 | 50KB 混合 HTML < 2ms（Release M 系列） |
| 线程安全 | 不同实例可并行，同一实例不可并发 |
| 内存 | 零泄漏（ASAN 验证），OOM 返回 NULL 不崩溃 |
| 容错 | 任意畸形输入零崩溃 |
| 覆盖率 | > 230 测试用例，全部 PASS |

---

## 2. 整体架构

### 项目结构

```
core/
├── include/xmarkup/
│   └── xmarkup.h              # 唯一公共头文件（C API，无 C++ ABI 依赖）
├── src/
│   ├── tokenizer.h / .cpp     # 词法分析器（12-状态 FSM）
│   ├── tree_builder.h / .cpp  # AST 构建器（隐式关闭 + Adoption Agency）
│   ├── style_resolver.h / .cpp # 样式解析器（标签映射 + CSS + 块级换行）
│   ├── entity_decoder.h / .cpp # HTML 实体解码器
│   ├── utf16_indexer.h / .cpp  # UTF-8 → UTF-16 索引映射
│   ├── logger.h / .cpp        # 日志系统（4 级别 + 回调输出）
│   ├── parser.h / .cpp        # 管线编排（ParserInternal）
│   └── api.cpp                # extern "C" API 薄封装
└── CMakeLists.txt             # 静态库 xmarkup_core

tests/
├── test_tokenizer.cpp         # 31 tests
├── test_tree_builder.cpp      # 25 tests
├── test_style_resolver.cpp    # 101 tests
├── test_entity_decoder.cpp    # 13 tests
├── test_utf16_indexer.cpp     # 9 tests
├── test_api.cpp               # 60 tests  ← 集成测试，覆盖完整管线
├── bench_helpers.h            # Benchmark 生成器
└── benchmark.cpp              # 23 个 Google Benchmark case
```

### 模块依赖关系

```
api.cpp (C API 薄封装)
   │
   ▼
parser.cpp (管线编排)
   │
   ├── tokenizer      →  标准库独立
   ├── tree_builder   →  依赖 tokenizer 的 Token
   ├── style_resolver →  依赖 tree_builder 的 ASTNode + entity_decoder
   ├── entity_decoder →  标准库独立
   └── utf16_indexer  →  标准库独立

logger →  全局静态，被所有模块引用
```

---

## 3. 处理管线（四阶段）

```
HTML 字符串 (UTF-8)
       │
       ▼
┌──────────────┐
│  Tokenizer   │  12-状态有限状态机
│              │  Token.tag_name 为 owned std::string（已小写化）
│              │  跳过 script/style/noscript/textarea/title/comment
└──────┬───────┘
       │ Token[]
       ▼
┌──────────────┐
│ TreeBuilder  │  栈式 AST 构建
│              │  + 隐式关闭 6 规则（始终生效）
│              │  + Adoption Agency（enable_autocorrect 控制）
│              │  + Scope Boundary 防跨容器关闭
│              │  + 最大嵌套深度截断
└──────┬───────┘
       │ ASTNode
       ▼
┌──────────────┐
│StyleResolver │  DFS 遍历 AST，同步完成：
│+ EntityDecoder│  - 标签→tag_type 映射
│               │  - HTML 实体解码
│               │  - CSS 行内样式解析 + 标准化
│               │  - 空白折叠（<pre> 内保留）
│               │  - 块级元素换行分隔
│               │  - <source> 父标签上下文感知
└──────┬───────┘
       │ FlattenResult{text, spans[byte_offset]}
       ▼
┌──────────────┐
│ UTF16Indexer │  单趟扫描 byte → utf16 映射表
│              │  二分查找 byte_to_utf16()
└──────┬───────┘
       │
       ▼
   XMResult{text(UTF-8), spans[](UTF-16)}
```

### 性能占比（50KB Realistic HTML, Release）

| 阶段 | 占比 | 说明 |
|:--|:--:|:--|
| Tokenizer | ~21% | 状态机逐字节扫描 |
| TreeBuilder | ~25% | 栈操作 + 隐式关闭判定 |
| StyleResolver | ~47% | CSS 解析 + 字符串处理 |
| UTF16Indexer | ~5% | 单趟线性扫描 |
| **总耗时** | **~1.4ms** | 50KB 输入, Release M 系列 |

StyleResolver 占比最高，因其涉及 CSS 字符串解析和多种颜色值标准化。

---

## 4. 数据模型

### 4.1 公共 API 类型（xmarkup.h）

```c
struct XMConfig {           // 解析器配置（栈分配，只读一次）
    uint8_t    enable_autocorrect;   // 1=启用 Adoption Agency
    uint16_t   max_nesting_depth;    // 最大嵌套层数（默认 256）
    float      base_font_size;       // 基准字号（px，用于 em/rem/% 换算）
    void*      log_callback;         // 日志回调函数（NULL=静默）
    void*      log_context;          // 回调上下文指针
    int        log_level;            // 最低日志级别（默认 ERROR）
};

struct XMResult {           // 解析结果（由 parse 分配，result_free 释放）
    XMError       error;             // 错误码
    const char*   text;              // 纯文本 UTF-8（终止符安全）
    uint32_t      text_len;          // 文本字节长度
    const XMSpan* spans;             // 样式区间数组
    uint32_t      span_count;        // span 数量
};

struct XMSpan {             // 样式区间（扁平数组，O(N) 遍历）
    XMRange     range;               // [start, end) UTF-16 索引
    int         tag;                 // XMTagType（0=无标签）
    int         style;               // XMStyleType（0=无样式）
    const char* value;               // 属性/样式值（可为 NULL）
    uint32_t    value_len;           // 值字节长度
};
```

### 4.2 标签映射（多对一）

语义等价的 HTML 标签共享同一个 `XMTagType`：

| XMTagType | 值 | HTML 标签 |
|:--|:--:|:--|
| BOLD | 1 | `<b>`, `<strong>` |
| ITALIC | 2 | `<i>`, `<em>` |
| UNDERLINE | 3 | `<u>` |
| STRIKETHROUGH | 4 | `<s>`, `<strike>`, `<del>` |
| SUBSCRIPT | 5 | `<sub>` |
| SUPERSCRIPT | 6 | `<sup>` |
| MARK | 7 | `<mark>` |
| CODE | 8 | `<code>` |
| PARAGRAPH | 20 | `<p>` |
| HEADING_1 ~ 6 | 21~26 | `<h1>` ~ `<h6>` |
| BLOCKQUOTE | 27 | `<blockquote>` |
| PREFORMATTED | 28 | `<pre>` |
| LINK | 40 | `<a>` |
| IMAGE | 41 | `<img>` |
| VIDEO / AUDIO | 42~45 | `<video>`, `<audio>`, `<source>` |
| TABLE 系列 | 60~63 | `<table>`, `<tr>`, `<td>`, `<th>` |
| LIST 系列 | 50~52 | `<ul>`, `<ol>`, `<li>` |
| 语义块级 | 74~86 | `<article>`, `<section>`, `<header>` 等 13 种 |

### 4.3 CSS 样式映射

| XMStyleType | 值 | CSS 属性 | 值标准化 |
|:--|:--:|:--|:--|
| FOREGROUND_COLOR | 1 | `color` | `#RRGGBB`（大写） |
| BACKGROUND_COLOR | 2 | `background-color` | `#RRGGBB` |
| FONT_SIZE | 3 | `font-size` | px 数字（em/pt/%→px） |
| FONT_WEIGHT | 4 | `font-weight` | 原值透传 |
| FONT_STYLE | 5 | `font-style` | 原值透传 |
| TEXT_DECORATION | 6 | `text-decoration` | 原值透传 |
| LINE_HEIGHT | 7 | `line-height` | 原值透传 |
| TEXT_ALIGN | 8 | `text-align` | 原值透传 |
| LETTER_SPACING | 9 | `letter-spacing` | px 数字（同 font-size） |
| MEDIA_TYPE | 10 | `<source>` type | 原值透传 |
| MEDIA_QUERY | 11 | `<source>` media | 原值透传 |

---

## 5. 模块详解

### 5.1 Tokenizer — 词法分析

**文件：** `tokenizer.h / .cpp`（~410 行）

手写有限状态机，**12 个状态**：

```
DATA → TAG_OPEN → TAG_NAME → BEFORE_ATTR_NAME → ATTR_NAME
  ↑       │                      ↑                    │
  │       ├→ END_TAG_OPEN        │                    │
  │       └→ COMMENT             │                    │
  │                              └→ AFTER_ATTR_NAME → ATTR_VALUE_*_Q
  └────────────────────────────────────────────────── SELF_CLOSING
```

关键设计：

| 特性 | 说明 |
|:--|:--|
| 零拷贝输入 | `std::string_view` 指向原始 HTML，无内存分配 |
| 批量文本 | DATA 下连续文本合并为单个 TEXT Token |
| 标签名小写化 | 输出 `std::string`（owned），`<DIV>` → `"div"` |
| RAWTEXT 跳过 | `<script>`, `<style>`, `<noscript>`, `<textarea>`, `<title>` 整体跳过，不以 HTML 解析内部内容 |
| 容错 | `<` 后非字母 → 文本；未闭合标签 → 输出已解析部分 |

### 5.2 TreeBuilder — AST 构建

**文件：** `tree_builder.h / .cpp`（~375 行）

栈式 AST 构建，管理节点嵌套关系：

```
栈底: ROOT → [div] → [p] → [b]    ← 入栈
                             ↓ 遇到 </b>
栈底: ROOT → [div] → [p]          ← 弹出匹配
```

#### 隐式关闭 6 规则（始终生效，HTML5 规范）

| 规则 | 父标签 | 触发条件 |
|:--|:--|:--|
| 1 | `<p>` | 遇任何块级元素（含自身） |
| 2 | `<li>` | 遇 `<li>` |
| 3 | `<dt>` / `<dd>` | 互相关闭 |
| 4 | `<tr>` | 遇 `<tr>` |
| 5 | `<td>` / `<th>` | 遇 `<td>` / `<th>` / `<tr>` |
| 6 | `<h1>`~`<h6>` | 遇块级元素 |

作用域边界（`scope_boundary_set`）阻止跨容器扫描：`div, blockquote, pre, table, ul, ol, video, audio, article, section, header, footer, main, nav, aside`。

#### Adoption Agency（`enable_autocorrect` 控制）

当行内格式化标签跨块级元素边界时，自动重建到块内：

```html
<b>text<p>para</p>   →   <b>text</b><p><b>para</b></p>
```

重建深度上限 `kMaxAdoptionDepth = 32`，`span`/`sub`/`sup` 不参与重建（保留包装层）。

### 5.3 StyleResolver — 样式解析

**文件：** `style_resolver.h / .cpp`（~670 行）

DFS 遍历 AST，单次遍历完成 7 项工作：

```
对于每个 ELEMENT 节点：
  1. map_tag() → 标签→XMTagType
  2. 如果是 <source> → 查父标签栈（video 或 audio）
  3. 块级元素 → 进入前 ensure_newline()
  4. 记录 span_start（byte offset）
  5. 压入 parent_stack_
  6. 递归处理子节点（传递 inside_pre 参数）
  7. 弹出 parent_stack_
  8. Void 元素 → 插入 U+FFFC / \n 占位符
  9. 块级元素 → 退出后 ensure_newline()
  10. 更新 byte_end
  11. 解析 style 属性 → add_style_spans()
  12. 提取 <source> 的 type/media → MEDIA_TYPE / MEDIA_QUERY spans
```

#### CSS 行内样式解析

支持 11 个属性。解析器为分号分隔的 `property:value` 循环：

1. 跳过空白，读取属性名到 `:`
2. 去尾部空白
3. 跳过空白，读取值到 `;`
4. 去尾部空白，剥离 `!important`（大小写不敏感）
5. 属性名 → 映射 `XMStyleType`
6. 值标准化（颜色→`#RRGGBB`，字号/字间距→px）

#### 长度值公共工具

`font-size` 和 `letter-spacing` 复用同一套单位换算函数：

```
16px  →  16          原值
1.5em →  24          × base_font_size
12pt  →  16          × 1.333
150%  →  24          × base_font_size / 100
1.5   →  1.5         无单位透传
```

#### 块级元素换行

每个块级元素进入前和退出后各执行一次 `ensure_newline()`：
- 如果文本末尾不是 `\n`，追加一个
- 连续块级元素不产生多余空行

### 5.4 EntityDecoder — 实体解码

**文件：** `entity_decoder.h / .cpp`（~255 行）

纯静态工具类，解码 HTML 实体：

| 类型 | 格式 | 示例 | 解码 |
|:--|:--|:--|:--|
| 命名实体 | `&name;` | `&amp;` | `&`（约 120 个） |
| 十进制 | `&#NNN;` | `&#60;` | `<` |
| 十六进制 | `&#xHHH;` | `&#x4e2d;` | `中` |

容错策略：
- 无分号命名实体 → 最长匹配（`&amp hello` → `& hello`）
- 非法数字实体（超范围、零值、surrogate） → **保留原文**
- 未知命名实体 → 保留原文

### 5.5 UTF16Indexer — 索引映射

**文件：** `utf16_indexer.h / .cpp`（~85 行）

将内部 UTF-8 byte offset 转换为平台通用的 UTF-16 索引：

| UTF-8 长度 | UTF-16 码元 | 例子 |
|:--:|:--:|:--|
| 1 字节 | 1 | `A` |
| 2 字节 | 1 | `é` |
| 3 字节 | 1 | `中` |
| 4 字节 | 2 | `😊`（surrogate pair） |

构建时单趟扫描，查询时 `std::lower_bound` 二分查找。非法续字节降级为 1→1 映射。

### 5.6 Logger — 日志系统

**文件：** `logger.h / .cpp`

全局静态类，通过 `XMConfig.log_callback` 输出。callback 为 NULL 时所有方法 O(1) 判空返回，零开销。

| 级别 | 用途 | 主要插桩位置 |
|:--|:--|:--|
| ERROR | 不可恢复错误 | parser.cpp（内存分配失败） |
| WARN | 容错决策 | tree_builder（隐式关闭、adoption） |
| INFO | 关键节点 | parser.cpp（解析开始/结束） |
| TRACE | 详细步骤 | tokenizer（标签小写化）、style_resolver（CSS 标准化） |

### 5.7 Parser + API — 管线编排

**文件：** `parser.h / .cpp`, `api.cpp`

`ParserInternal::parse()` 串联 5 步：

```
Tokenizer → TreeBuilder → StyleResolver → UTF16Indexer → 组装 XMResult
```

内存管理：

```
xmarkup_create()     分配 ParserInternal（std::nothrow）
    │
xmarkup_parse()      分配 XMResult，内部指针指向 owned_* 成员
    │                下次 parse() 调用前有效
xmarkup_result_free() 仅释放 XMResult 结构体
    │
xmarkup_destroy()    释放 ParserInternal 及所有内部数据
```

`api.cpp` 是 `extern "C"` 薄封装，将 C++ 类暴露为不透明 `XMParser*` 句柄。

---

## 6. 关键设计决策

### 6.1 为什么从零手写而非 libxml2 / gumbo

| 对比项 | XMarkup | libxml2 / gumbo |
|:--|:--|:--|
| 覆盖范围 | 移动端富文本子集（~30 标签） | 全部 HTML5 规范 |
| 代码体积 | ~2800 行 | 数万行 |
| 输出 | 纯文本 + span 区间 | DOM 树 |
| 性能 | 50KB < 2ms | 更重，需后处理才能得到文本+区间 |
| 外部依赖 | 无 | C 库需跨平台编译 |

### 6.2 UTF-16 索引而非 UTF-8

Java `String.charAt()`、Swift `NSString.length`、ArkTS `string.length` 都是 UTF-16 码元计数。输出 UTF-16 索引让桥接层无需任何换算即可直接用平台 API 定位文本区间。

### 6.3 扁平 span 数组而非树形结构

桥接层渲染时只需一个 `for` 循环遍历 spans 数组，O(N) 复杂度。嵌套树需要递归遍历或压栈。

### 6.4 多对一标签映射

`<b>` 和 `<strong>` → `XM_TAG_BOLD`，桥接层只需处理一个 tag 类型，无需判断等价关系。

### 6.5 单位换算在核心层

`font-size` 和 `letter-spacing` 的 em/rem/pt/% 换算统一在核心层完成，输出 px 数值。三端桥接层直接消费，不需要各自实现单位换算。

---

## 7. 接口规范

### 7.1 Span 解读规则

| tag | style | 含义 |
|:--:|:--:|:--|
| ≠ 0 | = 0 | 标签语义 span（加粗、链接等） |
| = 0 | ≠ 0 | CSS 样式 span（颜色、字号等） |
| ≠ 0 | ≠ 0 | **不会出现**，标签和样式是独立 span |

### 7.2 value 字段含义

| 上下文 | value 内容 |
|:--|:--|
| `XM_TAG_LINK` | href 属性值 |
| `XM_TAG_IMAGE` | src 属性值 |
| `XM_TAG_VIDEO` / `XM_TAG_AUDIO` | src 属性值 |
| `XM_TAG_VIDEO_SOURCE` / `XM_TAG_AUDIO_SOURCE` | src 属性值 |
| `XM_STYLE_FOREGROUND_COLOR` | `#RRGGBB` |
| `XM_STYLE_BACKGROUND_COLOR` | `#RRGGBB` |
| `XM_STYLE_FONT_SIZE` | px 数字字符串，如 `"24"` |
| `XM_STYLE_LETTER_SPACING` | px 数字字符串，如 `"2"` |
| `XM_STYLE_MEDIA_TYPE` | MIME 类型，如 `"video/mp4"` |
| `XM_STYLE_MEDIA_QUERY` | 媒体查询条件 |

---

## 8. 测试策略

### 8.1 测试金字塔

```
     ╱╲
    ╱  ╲          集成测试 (test_api.cpp, 60 tests)
   ╱    ╲
  ╱────────╲      模块测试（各模块独立 179 tests）
 ╱────────────╲
╱────────────────╲   Benchmark (23 cases, Google Benchmark)
```

### 8.2 覆盖重点

| 维度 | 方法 |
|:--|:--|
| 正常路径 | 每种标签/CSS 属性至少 1 个正向测试 |
| 边界 | 空输入、超大值、负数、嵌套极限 |
| 容错 | 畸形 HTML、乱序嵌套、非法属性 |
| 性能回归 | CI 中 3 个 PerfRegression 用例 |
| 线程安全 | 8 线程并发解析验证无冲突 |
| 内存 | ASAN 构建验证无泄漏/越界 |

### 8.3 当前覆盖统计

| 模块 | 测试数 | 覆盖率重点 |
|:--|:--:|:--|
| Tokenizer | 31 | 属性解析、RAWTEXT 跳过、大小写、unicode 容错 |
| TreeBuilder | 25 | 隐式关闭 6 规则、Adoption 4 场景、深度边界 |
| StyleResolver | 101 | 标签映射/CSS 11 属性/颜色 5 格式/字号 7 单位/块级换行 18 类 |
| EntityDecoder | 13 | 实体 3 类型、容错 4 场景 |
| UTF16Indexer | 9 | ASCII/中文/Emoji/非法 UTF-8/多 4 字节 |
| API 集成 | 60 | 完整管线、错误码全覆、性能回归 3、线程安全、日志 |
| **合计** | **239** | 全部 PASS |

---

## 9. 性能基线

### Release（Apple M 系列）

| 输入 | 耗时 | 吞吐量 |
|:--|:--:|:--:|
| 1 KB（聊天消息） | 0.02 ms | 42.7 MiB/s |
| 50 KB（文章正文） | 1.4 ms | 35.6 MiB/s |
| 100 KB | 2.4 ms | 40.1 MiB/s |
| 1 MB | 27.5 ms | 36.4 MiB/s |
| 8 线程并发 × 50KB | — | ~245 MiB/s（合计） |

### 特殊场景（50KB）

| 场景 | 耗时 | 备注 |
|:--|:--:|:--|
| 实体密集 | 0.39 ms | 124 MiB/s，SIMD 可向量化 |
| 纯文本无标签 | 0.82 ms | Tokenizer 极致快 |
| 重型样式 | 0.80 ms | CSS 解析占 75% |
| 重型标签 | 1.92 ms | TreeBuilder 占 40% |
| 深层嵌套（1000 层） | 0.23 ms | 截断保护 |
