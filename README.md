# XMarkup

高性能、线程安全的 HTML 富文本解析引擎，输出纯文本 + UTF-16 索引样式区间，供 iOS / Android / 鸿蒙三端桥接层消费。

## 特性

- **C++17 从零手写** — 不依赖第三方 HTML 解析库，完全掌控代码和性能
- **零拷贝词法分析** — 手写 15 状态有限状态机，`std::string_view` 直接引用原始输入
- **UTF-16 索引输出** — 内部 UTF-8 处理，输出 TextRange 使用 UTF-16 索引，无缝对接 Java / Swift / ArkTS
- **`extern "C"` 扁平 API** — 6 个函数，ABI 稳定，适用于 JNI / N-API / Swift 互操作
- **自动纠错** — 乱序嵌套、未闭合标签、多余闭合标签自动修复
- **CSS 行内样式** — 解析 `style` 属性，颜色名称 → HEX、em/rem/pt → px 单位换算
- **HTML 实体解码** — 命名实体（`&amp;`）、十进制（`&#60;`）、十六进制（`&#x3c;`）
- **安全防护** — 嵌套深度限制、恶意输入不崩溃、线程安全
- **极致轻量** — 静态库 101KB

## 性能

| 指标 | 数值 |
|------|------|
| 50KB HTML 解析耗时 | 9ms |
| 10000 层深度嵌套 | 3ms，不崩溃 |
| 8 线程 × 100 次并发 | 零错误 |
| 静态库体积 | 101KB |
| 测试覆盖 | 85 个测试，100% 通过（含 ASAN） |

## 快速开始

### 构建

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

### 运行测试

```bash
cd build/tests && ctest --output-on-failure
```

### ASAN 测试

```bash
cmake -S . -B build-asan -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_CXX_FLAGS="-fsanitize=address,undefined -fno-omit-frame-pointer"
cmake --build build-asan
cd build-asan/tests && ctest --output-on-failure
```

### 最小使用示例

```c
#include "xmarkup/xmarkup.h"
#include <stdio.h>

int main() {
    // 1. 创建解析器
    XMConfig cfg = {1, 256, 16};  // 自动纠错 / 最大深度256 / 基准字号16px
    XMParser* parser = xmarkup_create(&cfg);

    // 2. 解析 HTML
    const char* html = "<b>Hello</b> <a href=\"https://example.com\">World</a>";
    XMResult* result = xmarkup_parse(parser, html, strlen(html));

    // 3. 读取结果
    printf("Text: %s\n", result->text);
    printf("Spans: %u\n", result->span_count);

    for (uint32_t i = 0; i < result->span_count; i++) {
        XMSpan* s = &result->spans[i];
        printf("  [%u-%u] tag=%d style=%d value=%s\n",
               s->range.start, s->range.end, s->tag, s->style,
               s->value ? s->value : "(null)");
    }

    // 4. 释放资源
    xmarkup_result_free(result);
    xmarkup_destroy(parser);
    return 0;
}
```

输出：

```
Text: Hello World
Spans: 2
  [0-5] tag=1 style=0 value=(null)         # XM_TAG_BOLD
  [6-11] tag=40 style=0 value=https://example.com  # XM_TAG_LINK
```

## API 概览

| 函数 | 说明 |
|------|------|
| `xmarkup_create(config)` | 创建解析器实例 |
| `xmarkup_destroy(parser)` | 销毁解析器实例 |
| `xmarkup_parse(parser, html, length)` | 解析 HTML，返回 `XMResult*` |
| `xmarkup_result_free(result)` | 释放解析结果 |
| `xmarkup_last_error(parser)` | 获取最近一次解析的错误码 |
| `xmarkup_error_string(error)` | 错误码转字符串 |

> 完整 API 参考见 [docs/api-reference.md](docs/api-reference.md)

## 项目结构

```
XMarkup/
├── core/                          # C++17 核心引擎
│   ├── include/xmarkup/xmarkup.h  # 唯一公共头文件
│   └── src/                       # 内部实现（7 个模块）
├── tests/                         # GoogleTest 测试（85 个测试用例）
├── bridges/                       # 三端桥接层（子项目 B，待启动）
└── docs/                          # 文档
```

## 支持的 HTML 标签

### 文本样式
`<b>`, `<strong>`, `<i>`, `<em>`, `<u>`, `<s>`, `<del>`, `<sub>`, `<sup>`, `<mark>`, `<code>`

### 段落结构
`<p>`, `<h1>`~`<h6>`, `<blockquote>`, `<pre>`, `<div>`, `<span>`

### 链接与媒体
`<a href>`, `<img src>`, `<video>`, `<source>`, `<audio>`

### 列表
`<ul>`, `<ol>`, `<li>`

### 表格
`<table>`, `<tr>`, `<td>`, `<th>`

### 其他
`<br>`, `<hr>`

### 自动跳过
`<script>`, `<style>`, `<noscript>`（整体跳过，不产生任何 Token）
`<!-- -->` 注释（静默跳过）

## 支持的 CSS 属性（inline style）

| 属性 | 示例 | 标准化输出 |
|------|------|-----------|
| `color` | `red`, `#f00`, `#ff0000`, `rgb(255,0,0)` | `#FF0000` |
| `background-color` | `#00ff00` | `#00FF00` |
| `font-size` | `16px`, `1.5em`, `12pt`, `150%` | `24`（px 整数） |
| `font-weight` | `bold`, `700` | 原样输出 |
| `font-style` | `italic` | 原样输出 |
| `text-decoration` | `underline` | 原样输出 |
| `text-align` | `center` | 原样输出 |
| `line-height` | `1.5` | 原样输出 |
| `letter-spacing` | `2px` | 原样输出 |

## 技术栈

- **语言**：C++17
- **构建**：CMake 3.16+
- **测试**：GoogleTest v1.14.0
- **编码**：内部 UTF-8，输出 UTF-16 索引
- **无外部依赖**：除 GoogleTest（仅测试）

## 文档

- [API 参考文档](docs/api-reference.md) — 完整 C API 函数、枚举、结构体说明
- [架构文档](docs/architecture.md) — 模块设计、数据流、扩展指南
- [设计规格说明书](docs/superpowers/specs/2026-06-05-xmarkup-core-design.md) — 完整设计文档

## 许可

MIT
