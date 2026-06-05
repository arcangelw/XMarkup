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
│   │   ├── tree_builder.h            # 栈式 AST 构建器
│   │   ├── tree_builder.cpp
│   │   ├── style_resolver.h          # CSS 行内样式解析 + 映射
│   │   ├── style_resolver.cpp
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
│   ├── test_utf16_indexer.cpp
│   ├── test_api.cpp
│   └── test_data/                    # 测试用 HTML 文件
│       ├── simple.html
│       ├── nested_mismatch.html
│       ├── stress_50kb.html
│       └── malicious.html
│
├── bridges/                          # 三端桥接层（子项目 B 预留）
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
    const char*   text;
    uint32_t      text_len;
    const XMSpan* spans;
    uint32_t      span_count;
} XMResult;

/* 配置 */
typedef struct XMConfig {
    uint8_t enable_autocorrect;
    uint8_t max_nesting_depth;
} XMConfig;

/* 不透明解析器句柄 */
typedef struct XMParser XMParser;

/* 生命周期 */
XMParser* xmarkup_create(const XMConfig* config);
void      xmarkup_destroy(XMParser* parser);

/* 核心解析 */
XMResult* xmarkup_parse(XMParser* parser, const char* html, size_t length);
void      xmarkup_result_free(XMResult* result);

#ifdef __cplusplus
}
#endif

#endif /* XMARKUP_H */
```

### 3.2 数据契约说明

| 结构体 | 职责 | 内存归属 |
|--------|------|---------|
| `XMParser` | 解析器实例，持有配置和内部状态 | 由 `xmarkup_create` 分配，`xmarkup_destroy` 释放 |
| `XMResult` | 解析结果，含纯文本 + 样式数组 | 由 `xmarkup_parse` 分配，`xmarkup_result_free` 释放 |
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

---

### 4.3 样式解析器（Style Resolver）

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
| `<source>` | `XM_TAG_VIDEO_SOURCE` | value = src（视频地址），见 10.3 节 |
| `<audio>` | `XM_TAG_AUDIO` | 与 video 对称，见 10.3.6 节 |
| `<source>` (audio 内) | `XM_TAG_AUDIO_SOURCE` | value = src（音频地址） |
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

| 输入格式 | 标准化输出 | 示例 |
|---------|-----------|------|
| 颜色名 | `#RRGGBB` | `red` → `#FF0000` |
| `rgb(r,g,b)` | `#RRGGBB` | `rgb(255,0,0)` → `#FF0000` |
| `rgba(r,g,b,a)` | `#RRGGBBAA` | `rgba(255,0,0,0.5)` → `#FF000080` |
| `#RGB` | `#RRGGBB` | `#F00` → `#FF0000` |
| `16px` / `1em` | `16` | 去除 px/em/rem/pt 单位 |
| `bold` / `700` | `bold` | font-weight 标准化 |

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
│              │ 输出 AST（byte offset）
└──────┬───────┘
       │ AST
       ↓
┌──────────────┐
│StyleResolver │ DFS 遍历，标签映射 + CSS 解析
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
   { text(UTF-8), spans[](UTF-16 ranges) }
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
| TreeBuilder | 正常嵌套、兄弟节点 | 乱序纠错、未闭合、多余闭合、深度限制 | 50KB 压力测试 < 15ms | — |
| StyleResolver | 标签映射、CSS 解析、值提取 | 未知标签、非法 CSS、空属性 | — | — |
| UTF16Indexer | ASCII、中文、Emoji、混合内容 | 空文本、非法 UTF-8 | — | — |
| API 集成 | 完整管线 | 空输入、恶意输入、千万层嵌套 | 50KB 压力测试 | 多线程并发 |

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
| iOS | Swift 直接调用 C API（或 ObjC++ 薄封装） | `NSAttributedString` |
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
