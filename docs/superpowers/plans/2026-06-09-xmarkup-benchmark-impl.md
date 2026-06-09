# XMarkup 性能测试 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 为 XMarkup C++ 核心引擎建立系统化性能测试 — Google Benchmark 18 个 case + GoogleTest 3 个回归 case

**架构：** Google Benchmark + GoogleTest 混合方案。共享辅助头 `bench_helpers.h` 提供 HTML 生成器、分阶段计时器和内存追踪器。Benchmark 编译为独立 target `xmarkup_bench`，通过 CMake option `XMARKUP_BUILD_BENCHMARKS` 控制。

**技术栈：** C++17, CMake, GoogleTest, Google Benchmark v1.8.3

---

## 文件结构

| 文件 | 操作 | 职责 |
|------|------|------|
| `tests/CMakeLists.txt` | 修改 | 新增 Google Benchmark FetchContent + xmarkup_bench target |
| `tests/bench_helpers.h` | 新增 | HTML 生成器 + 分阶段计时器 + 内存追踪器 |
| `tests/benchmark.cpp` | 新增 | 18 个 Google Benchmark case |
| `tests/test_api.cpp` | 修改 | 新增 3 个性能回归 case |

---

### 任务 1：CMake 集成 + 验证编译

**文件：**
- 修改：`tests/CMakeLists.txt`
- 创建：`tests/benchmark.cpp`（空骨架）

- [ ] **步骤 1：修改 tests/CMakeLists.txt 添加 Google Benchmark**

在现有 `endforeach()` 之后追加：

```cmake
# Google Benchmark（可选构建）
option(XMARKUP_BUILD_BENCHMARKS "Build performance benchmarks" OFF)
if(XMARKUP_BUILD_BENCHMARKS)
    FetchContent_Declare(
        googlebench
        GIT_REPOSITORY https://github.com/google/benchmark.git
        GIT_TAG        v1.8.3
    )
    set(BENCHMARK_ENABLE_TESTING OFF CACHE BOOL "" FORCE)
    set(BENCHMARK_ENABLE_INSTALL OFF CACHE BOOL "" FORCE)
    FetchContent_MakeAvailable(googlebench)

    add_executable(xmarkup_bench benchmark.cpp)
    target_link_libraries(xmarkup_bench
        PRIVATE xmarkup_core benchmark::benchmark_main
    )
    target_include_directories(xmarkup_bench
        PRIVATE ${CMAKE_SOURCE_DIR}/core/src
    )
endif()
```

- [ ] **步骤 2：创建 benchmark.cpp 骨架**

```cpp
#include <benchmark/benchmark.h>
#include "xmarkup/xmarkup.h"

// 占位 benchmark，验证编译和链接
static void BM_Placeholder(benchmark::State& state) {
    for (auto _ : state) {
        // 空操作
    }
}
BENCHMARK(BM_Placeholder);

BENCHMARK_MAIN();
```

- [ ] **步骤 3：验证普通构建不受影响**

运行：`cd /Users/arcangelw/GitHub/XMarkup/build && cmake .. && cmake --build . 2>&1 | tail -5`
预期：正常编译，无 benchmark 相关输出

- [ ] **步骤 4：验证 benchmark 构建**

运行：`cd /Users/arcangelw/GitHub/XMarkup && mkdir -p build-bench && cd build-bench && cmake .. -DXMARKUP_BUILD_BENCHMARKS=ON 2>&1 | tail -10 && cmake --build . 2>&1 | tail -10`
预期：编译成功，生成 `tests/xmarkup_bench`

- [ ] **步骤 5：运行 benchmark 骨架**

运行：`cd /Users/arcangelw/GitHub/XMarkup/build-bench && ./tests/xmarkup_bench 2>&1 | head -10`
预期：输出 benchmark 表格，包含 BM_Placeholder 一行

- [ ] **步骤 6：Commit**

```bash
cd /Users/arcangelw/GitHub/XMarkup
git add tests/CMakeLists.txt tests/benchmark.cpp
git commit -m "feat(bench): CMake 集成 Google Benchmark + 骨架验证"
```

---

### 任务 2：bench_helpers.h — HTML 生成器

**文件：**
- 创建：`tests/bench_helpers.h`

- [ ] **步骤 1：创建 bench_helpers.h，实现 HtmlGenerator**

```cpp
#pragma once

#include <string>
#include <cstddef>

// ============================================================
// HTML 生成器 — 为 benchmark 生成各种模式的测试输入
// ============================================================

struct HtmlGenerator {
    /// 混合 HTML 模板段落（约 200 字节）
    static const char* mixed_template() {
        return
            "<p><b style=\"color:#ff0000\">Bold text 12345</b>"
            "<i>Italic text</i></p>"
            "<ul><li>Item A</li><li>Item B</li></ul>"
            "<a href=\"https://example.com/page\">Link text here</a>"
            "<table><tr><td>Cell A</td><td>Cell B</td></tr></table>"
            "<div><p>Nested paragraph with <b>bold</b> content</p></div>";
    }

    /// 生成指定大小的混合 HTML
    static std::string mixed(size_t target_bytes) {
        std::string result;
        result.reserve(target_bytes);
        const char* tmpl = mixed_template();
        size_t tmpl_len = std::char_traits<char>::length(tmpl);
        while (result.size() + tmpl_len <= target_bytes) {
            result += tmpl;
        }
        if (result.size() < target_bytes) {
            result.append(tmpl, target_bytes - result.size());
        }
        return result;
    }

    /// 纯文本，无标签 — 测试 tokenizer 的字符批量化效率
    static std::string pure_text(size_t target_bytes) {
        return std::string(target_bytes, 'A');
    }

    /// 密集嵌套标签 — 测试 TreeBuilder 栈操作效率
    static std::string heavy_tags(size_t target_bytes) {
        std::string result;
        result.reserve(target_bytes);
        const char* pattern = "<b><i><u>text</u></i></b>";
        size_t pat_len = std::char_traits<char>::length(pattern);
        while (result.size() + pat_len <= target_bytes) {
            result += pattern;
        }
        if (result.size() < target_bytes) {
            result.append(pattern, target_bytes - result.size());
        }
        return result;
    }

    /// 大量 CSS inline style — 测试 StyleResolver 解析效率
    static std::string heavy_style(size_t target_bytes) {
        std::string result;
        result.reserve(target_bytes);
        const char* pattern =
            "<span style=\"color:#ff0000;font-size:16px;font-weight:bold;"
            "text-align:center;line-height:1.5\">text</span>";
        size_t pat_len = std::char_traits<char>::length(pattern);
        while (result.size() + pat_len <= target_bytes) {
            result += pattern;
        }
        if (result.size() < target_bytes) {
            result.append(pattern, target_bytes - result.size());
        }
        return result;
    }

    /// 深层嵌套 — 测试栈深度性能
    static std::string deep_nesting(int depth) {
        std::string result;
        result.reserve(depth * 10);
        for (int i = 0; i < depth; i++) {
            result += "<div>";
        }
        result += "text";
        for (int i = 0; i < depth; i++) {
            result += "</div>";
        }
        return result;
    }

    /// 大表格 — 测试隐式关闭在大规模表格中的开销
    static std::string wide_table(int rows, int cols) {
        std::string result = "<table>";
        for (int r = 0; r < rows; r++) {
            result += "<tr>";
            for (int c = 0; c < cols; c++) {
                result += "<td>Cell</td>";
            }
            result += "</tr>";
        }
        result += "</table>";
        return result;
    }

    /// 中英日韩 Emoji 混合 — 测试 UTF16Indexer 效率
    static std::string mixed_multilingual(size_t target_bytes) {
        const char* tmpl =
            "<p>Hello \xe4\xb8\x96\xe7\x95\x8c"       // 世界
            "\xe3\x81\x93\xe3\x82\x93\xe3\x81\xab\xe3\x81\xa1\xe3\x81\xaf" // こんにちは
            "\xed\x95\x9c\xea\xb5\xad"                   // 한국
            "\xf0\x9f\x98\x8a\xf0\x9f\x8e\x89</p>";     // 😊🎉
        std::string result;
        result.reserve(target_bytes);
        size_t tmpl_len = std::char_traits<char>::length(tmpl);
        while (result.size() + tmpl_len <= target_bytes) {
            result += tmpl;
        }
        if (result.size() < target_bytes) {
            result.append(tmpl, target_bytes - result.size());
        }
        return result;
    }

    /// Adoption agency 测试模式：N 个 <b>text<p>para</p>
    static std::string adoption_pattern(int count) {
        std::string html = "<div>";
        html.reserve(count * 30);
        for (int i = 0; i < count; i++) {
            html += "<b>text<p>para</p>";
        }
        html += "</div>";
        return html;
    }
};
```

- [ ] **步骤 2：验证编译（包含 bench_helpers.h 的空 benchmark）**

修改 `benchmark.cpp` 临时包含 `bench_helpers.h` 验证编译：

```cpp
#include <benchmark/benchmark.h>
#include "xmarkup/xmarkup.h"
#include "bench_helpers.h"

static void BM_HtmlGeneratorCheck(benchmark::State& state) {
    auto html = HtmlGenerator::mixed(1024);
    for (auto _ : state) {
        auto copy = html;  // 确保生成器代码不被优化掉
        benchmark::DoNotOptimize(copy);
    }
}
BENCHMARK(BM_HtmlGeneratorCheck);

BENCHMARK_MAIN();
```

运行：`cd /Users/arcangelw/GitHub/XMarkup/build-bench && cmake .. -DXMARKUP_BUILD_BENCHMARKS=ON && cmake --build . 2>&1 | tail -5`
预期：编译成功

- [ ] **步骤 3：运行验证**

运行：`./tests/xmarkup_bench --benchmark_filter=BM_HtmlGeneratorCheck 2>&1 | head -10`
预期：输出一行 benchmark 结果

- [ ] **步骤 4：Commit**

```bash
cd /Users/arcangelw/GitHub/XMarkup
git add tests/bench_helpers.h
git commit -m "feat(bench): HtmlGenerator — 7 种 HTML 模式生成器"
```

---

### 任务 3：bench_helpers.h — StageTimer + MemoryTracker

**文件：**
- 修改：`tests/bench_helpers.h`

- [ ] **步骤 1：在 bench_helpers.h 末尾添加 StageTimer**

在 `HtmlGenerator` 结构体之后追加：

```cpp
// ============================================================
// 分阶段计时器 — 测量各管线阶段耗时
// ============================================================

#include <chrono>
#include "tokenizer.h"
#include "tree_builder.h"
#include "style_resolver.h"
#include "utf16_indexer.h"
#include "parser.h"

struct StageTimer {
    uint64_t tokenizer_us;
    uint64_t tree_builder_us;
    uint64_t style_resolver_us;
    uint64_t utf16_indexer_us;
    uint64_t total_us;

    using Clock = std::chrono::high_resolution_clock;
    using TimePoint = std::chrono::time_point<Clock>;

    static uint64_t us_between(TimePoint start, TimePoint end) {
        return static_cast<uint64_t>(
            std::chrono::duration_cast<std::chrono::microseconds>(end - start).count());
    }

    static StageTimer measure(const char* html, size_t length, const XMConfig& cfg) {
        StageTimer t{};
        TimePoint t0, t1, t2, t3, t4;

        // 阶段 1：词法分析
        t0 = Clock::now();
        std::string_view html_view(html, length);
        xmarkup::Tokenizer tokenizer(html_view);
        std::vector<xmarkup::Token> tokens;
        while (tokenizer.has_next()) tokens.push_back(tokenizer.next());
        t1 = Clock::now();

        // 阶段 2：AST 构建
        xmarkup::TreeBuilder tree_builder(cfg.max_nesting_depth, cfg.enable_autocorrect);
        xmarkup::ASTNode ast = tree_builder.build(tokens);
        t2 = Clock::now();

        // 阶段 3：样式解析
        xmarkup::StyleResolver style_resolver(cfg.base_font_size);
        xmarkup::FlattenResult flat = style_resolver.resolve(ast);
        t3 = Clock::now();

        // 阶段 4：UTF-16 映射
        xmarkup::UTF16Indexer indexer;
        indexer.build(flat.text);
        t4 = Clock::now();

        t.tokenizer_us     = us_between(t0, t1);
        t.tree_builder_us  = us_between(t1, t2);
        t.style_resolver_us = us_between(t2, t3);
        t.utf16_indexer_us = us_between(t3, t4);
        t.total_us         = us_between(t0, t4);
        return t;
    }
};
```

- [ ] **步骤 2：在 bench_helpers.h 末尾添加 MemoryTracker**

在 `StageTimer` 之后追加：

```cpp
// ============================================================
// 内存追踪器 — 测量解析过程内存增量
// ============================================================

#ifdef __APPLE__
#include <mach/mach.h>
#elif defined(__linux__)
#include <fstream>
#endif

struct MemoryTracker {
    size_t peak_rss_kb;
    size_t delta_rss_kb;

    static size_t get_rss_kb() {
#ifdef __APPLE__
        struct mach_task_basic_info info;
        mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
        if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO,
                      (thread_info_t)&info, &count) == KERN_SUCCESS) {
            return info.resident_size / 1024;
        }
        return 0;
#elif defined(__linux__)
        std::ifstream ifs("/proc/self/status");
        std::string line;
        while (std::getline(ifs, line)) {
            if (line.compare(0, 6, "VmRSS:") == 0) {
                return std::stoul(line.substr(6)) ;  // 单位已经是 kB
            }
        }
        return 0;
#else
        return 0;
#endif
    }

    static MemoryTracker snapshot() {
        MemoryTracker mt;
        mt.peak_rss_kb = get_rss_kb();
        mt.delta_rss_kb = 0;
        return mt;
    }

    static MemoryTracker measure_parsing(const char* html, size_t length, const XMConfig& cfg) {
        size_t before = get_rss_kb();
        XMParser* p = xmarkup_create(&cfg);
        XMResult* r = xmarkup_parse(p, html, length);
        size_t after = get_rss_kb();
        xmarkup_result_free(r);
        xmarkup_destroy(p);
        MemoryTracker mt;
        mt.peak_rss_kb = after;
        mt.delta_rss_kb = (after > before) ? (after - before) : 0;
        return mt;
    }
};
```

- [ ] **步骤 3：验证编译**

运行：`cd /Users/arcangelw/GitHub/XMarkup/build-bench && cmake --build . 2>&1 | tail -5`
预期：编译成功

- [ ] **步骤 4：Commit**

```bash
cd /Users/arcangelw/GitHub/XMarkup
git add tests/bench_helpers.h
git commit -m "feat(bench): StageTimer 分阶段计时 + MemoryTracker 内存追踪"
```

---

### 任务 4：benchmark.cpp — 吞吐量基准（6 个 case）

**文件：**
- 修改：`tests/benchmark.cpp`

- [ ] **步骤 1：重写 benchmark.cpp，实现 6 个吞吐量基准**

```cpp
#include <benchmark/benchmark.h>
#include "xmarkup/xmarkup.h"
#include "bench_helpers.h"

// ============================================================
// 4.1 吞吐量基准（6 个）
// ============================================================

static void BM_Throughput_1KB(benchmark::State& state) {
    auto html = HtmlGenerator::mixed(1 * 1024);
    XMConfig cfg = {1, 256, 16.0f, nullptr, nullptr, XM_LOG_ERROR};
    for (auto _ : state) {
        XMParser* p = xmarkup_create(&cfg);
        XMResult* r = xmarkup_parse(p, html.c_str(), html.size());
        benchmark::DoNotOptimize(r);
        xmarkup_result_free(r);
        xmarkup_destroy(p);
    }
    state.SetBytesProcessed(state.iterations() * html.size());
}
BENCHMARK(BM_Throughput_1KB);

static void BM_Throughput_10KB(benchmark::State& state) {
    auto html = HtmlGenerator::mixed(10 * 1024);
    XMConfig cfg = {1, 256, 16.0f, nullptr, nullptr, XM_LOG_ERROR};
    for (auto _ : state) {
        XMParser* p = xmarkup_create(&cfg);
        XMResult* r = xmarkup_parse(p, html.c_str(), html.size());
        benchmark::DoNotOptimize(r);
        xmarkup_result_free(r);
        xmarkup_destroy(p);
    }
    state.SetBytesProcessed(state.iterations() * html.size());
}
BENCHMARK(BM_Throughput_10KB);

static void BM_Throughput_50KB(benchmark::State& state) {
    auto html = HtmlGenerator::mixed(50 * 1024);
    XMConfig cfg = {1, 256, 16.0f, nullptr, nullptr, XM_LOG_ERROR};
    for (auto _ : state) {
        XMParser* p = xmarkup_create(&cfg);
        XMResult* r = xmarkup_parse(p, html.c_str(), html.size());
        benchmark::DoNotOptimize(r);
        xmarkup_result_free(r);
        xmarkup_destroy(p);
    }
    state.SetBytesProcessed(state.iterations() * html.size());
}
BENCHMARK(BM_Throughput_50KB);

static void BM_Throughput_100KB(benchmark::State& state) {
    auto html = HtmlGenerator::mixed(100 * 1024);
    XMConfig cfg = {1, 256, 16.0f, nullptr, nullptr, XM_LOG_ERROR};
    for (auto _ : state) {
        XMParser* p = xmarkup_create(&cfg);
        XMResult* r = xmarkup_parse(p, html.c_str(), html.size());
        benchmark::DoNotOptimize(r);
        xmarkup_result_free(r);
        xmarkup_destroy(p);
    }
    state.SetBytesProcessed(state.iterations() * html.size());
}
BENCHMARK(BM_Throughput_100KB);

static void BM_Throughput_500KB(benchmark::State& state) {
    auto html = HtmlGenerator::mixed(500 * 1024);
    XMConfig cfg = {1, 256, 16.0f, nullptr, nullptr, XM_LOG_ERROR};
    for (auto _ : state) {
        XMParser* p = xmarkup_create(&cfg);
        XMResult* r = xmarkup_parse(p, html.c_str(), html.size());
        benchmark::DoNotOptimize(r);
        xmarkup_result_free(r);
        xmarkup_destroy(p);
    }
    state.SetBytesProcessed(state.iterations() * html.size());
}
BENCHMARK(BM_Throughput_500KB);

static void BM_Throughput_1MB(benchmark::State& state) {
    auto html = HtmlGenerator::mixed(1024 * 1024);
    XMConfig cfg = {1, 256, 16.0f, nullptr, nullptr, XM_LOG_ERROR};
    for (auto _ : state) {
        XMParser* p = xmarkup_create(&cfg);
        XMResult* r = xmarkup_parse(p, html.c_str(), html.size());
        benchmark::DoNotOptimize(r);
        xmarkup_result_free(r);
        xmarkup_destroy(p);
    }
    state.SetBytesProcessed(state.iterations() * html.size());
}
BENCHMARK(BM_Throughput_1MB);

BENCHMARK_MAIN();
```

- [ ] **步骤 2：编译并运行吞吐量 benchmark**

运行：`cd /Users/arcangelw/GitHub/XMarkup/build-bench && cmake --build . 2>&1 | tail -5 && ./tests/xmarkup_bench --benchmark_filter=BM_Throughput 2>&1`
预期：输出 6 行 benchmark 结果，含 MB/s 吞吐量

- [ ] **步骤 3：Commit**

```bash
cd /Users/arcangelw/GitHub/XMarkup
git add tests/benchmark.cpp
git commit -m "feat(bench): 吞吐量基准 — 6 个 Throughput case（1KB~1MB）"
```

---

### 任务 5：benchmark.cpp — 分阶段 + 内存 + 并发 + 特殊场景（12 个 case）

**文件：**
- 修改：`tests/benchmark.cpp`

- [ ] **步骤 1：在 `BENCHMARK(BM_Throughput_1MB)` 之后、`BENCHMARK_MAIN()` 之前追加分阶段 benchmark（4 个）**

```cpp
// ============================================================
// 4.2 分阶段耗时（4 个）
// ============================================================

static void BM_StageBreakdown_50KB(benchmark::State& state) {
    auto html = HtmlGenerator::mixed(50 * 1024);
    XMConfig cfg = {1, 256, 16.0f, nullptr, nullptr, XM_LOG_ERROR};
    StageTimer last{};
    for (auto _ : state) {
        last = StageTimer::measure(html.c_str(), html.size(), cfg);
        benchmark::DoNotOptimize(&last);
    }
    char label[128];
    snprintf(label, sizeof(label), "tok=%llu%% tree=%llu%% style=%llu%% utf16=%llu%%",
        (unsigned long long)(last.tokenizer_us * 100 / (last.total_us ? last.total_us : 1)),
        (unsigned long long)(last.tree_builder_us * 100 / (last.total_us ? last.total_us : 1)),
        (unsigned long long)(last.style_resolver_us * 100 / (last.total_us ? last.total_us : 1)),
        (unsigned long long)(last.utf16_indexer_us * 100 / (last.total_us ? last.total_us : 1)));
    state.SetLabel(label);
}
BENCHMARK(BM_StageBreakdown_50KB);

static void BM_StageBreakdown_HeavyTags(benchmark::State& state) {
    auto html = HtmlGenerator::heavy_tags(50 * 1024);
    XMConfig cfg = {1, 256, 16.0f, nullptr, nullptr, XM_LOG_ERROR};
    StageTimer last{};
    for (auto _ : state) {
        last = StageTimer::measure(html.c_str(), html.size(), cfg);
        benchmark::DoNotOptimize(&last);
    }
    char label[128];
    snprintf(label, sizeof(label), "tok=%llu%% tree=%llu%% style=%llu%% utf16=%llu%%",
        (unsigned long long)(last.tokenizer_us * 100 / (last.total_us ? last.total_us : 1)),
        (unsigned long long)(last.tree_builder_us * 100 / (last.total_us ? last.total_us : 1)),
        (unsigned long long)(last.style_resolver_us * 100 / (last.total_us ? last.total_us : 1)),
        (unsigned long long)(last.utf16_indexer_us * 100 / (last.total_us ? last.total_us : 1)));
    state.SetLabel(label);
}
BENCHMARK(BM_StageBreakdown_HeavyTags);

static void BM_StageBreakdown_HeavyStyle(benchmark::State& state) {
    auto html = HtmlGenerator::heavy_style(50 * 1024);
    XMConfig cfg = {1, 256, 16.0f, nullptr, nullptr, XM_LOG_ERROR};
    StageTimer last{};
    for (auto _ : state) {
        last = StageTimer::measure(html.c_str(), html.size(), cfg);
        benchmark::DoNotOptimize(&last);
    }
    char label[128];
    snprintf(label, sizeof(label), "tok=%llu%% tree=%llu%% style=%llu%% utf16=%llu%%",
        (unsigned long long)(last.tokenizer_us * 100 / (last.total_us ? last.total_us : 1)),
        (unsigned long long)(last.tree_builder_us * 100 / (last.total_us ? last.total_us : 1)),
        (unsigned long long)(last.style_resolver_us * 100 / (last.total_us ? last.total_us : 1)),
        (unsigned long long)(last.utf16_indexer_us * 100 / (last.total_us ? last.total_us : 1)));
    state.SetLabel(label);
}
BENCHMARK(BM_StageBreakdown_HeavyStyle);

static void BM_StageBreakdown_Multilingual(benchmark::State& state) {
    auto html = HtmlGenerator::mixed_multilingual(50 * 1024);
    XMConfig cfg = {1, 256, 16.0f, nullptr, nullptr, XM_LOG_ERROR};
    StageTimer last{};
    for (auto _ : state) {
        last = StageTimer::measure(html.c_str(), html.size(), cfg);
        benchmark::DoNotOptimize(&last);
    }
    char label[128];
    snprintf(label, sizeof(label), "tok=%llu%% tree=%llu%% style=%llu%% utf16=%llu%%",
        (unsigned long long)(last.tokenizer_us * 100 / (last.total_us ? last.total_us : 1)),
        (unsigned long long)(last.tree_builder_us * 100 / (last.total_us ? last.total_us : 1)),
        (unsigned long long)(last.style_resolver_us * 100 / (last.total_us ? last.total_us : 1)),
        (unsigned long long)(last.utf16_indexer_us * 100 / (last.total_us ? last.total_us : 1)));
    state.SetLabel(label);
}
BENCHMARK(BM_StageBreakdown_Multilingual);
```

- [ ] **步骤 2：追加内存 benchmark（3 个）**

```cpp
// ============================================================
// 4.3 内存基准（3 个）
// ============================================================

static void BM_Memory_50KB(benchmark::State& state) {
    auto html = HtmlGenerator::mixed(50 * 1024);
    XMConfig cfg = {1, 256, 16.0f, nullptr, nullptr, XM_LOG_ERROR};
    size_t max_delta = 0;
    for (auto _ : state) {
        auto mt = MemoryTracker::measure_parsing(html.c_str(), html.size(), cfg);
        if (mt.delta_rss_kb > max_delta) max_delta = mt.delta_rss_kb;
    }
    char label[64];
    snprintf(label, sizeof(label), "rss_delta=%zuKB (%.1fx input)",
        max_delta, max_delta * 1024.0 / html.size());
    state.SetLabel(label);
}
BENCHMARK(BM_Memory_50KB);

static void BM_Memory_500KB(benchmark::State& state) {
    auto html = HtmlGenerator::mixed(500 * 1024);
    XMConfig cfg = {1, 256, 16.0f, nullptr, nullptr, XM_LOG_ERROR};
    size_t max_delta = 0;
    for (auto _ : state) {
        auto mt = MemoryTracker::measure_parsing(html.c_str(), html.size(), cfg);
        if (mt.delta_rss_kb > max_delta) max_delta = mt.delta_rss_kb;
    }
    char label[64];
    snprintf(label, sizeof(label), "rss_delta=%zuKB (%.1fx input)",
        max_delta, max_delta * 1024.0 / html.size());
    state.SetLabel(label);
}
BENCHMARK(BM_Memory_500KB);

static void BM_Memory_1MB(benchmark::State& state) {
    auto html = HtmlGenerator::mixed(1024 * 1024);
    XMConfig cfg = {1, 256, 16.0f, nullptr, nullptr, XM_LOG_ERROR};
    size_t max_delta = 0;
    for (auto _ : state) {
        auto mt = MemoryTracker::measure_parsing(html.c_str(), html.size(), cfg);
        if (mt.delta_rss_kb > max_delta) max_delta = mt.delta_rss_kb;
    }
    char label[64];
    snprintf(label, sizeof(label), "rss_delta=%zuKB (%.1fx input)",
        max_delta, max_delta * 1024.0 / html.size());
    state.SetLabel(label);
}
BENCHMARK(BM_Memory_1MB);
```

- [ ] **步骤 3：追加并发 benchmark（2 个）**

```cpp
// ============================================================
// 4.4 并发性能（2 个）
// ============================================================

#include <thread>
#include <atomic>
#include <vector>

static void BM_Concurrent_8Threads(benchmark::State& state) {
    auto html = HtmlGenerator::mixed(50 * 1024);
    for (auto _ : state) {
        std::atomic<uint64_t> total_bytes{0};
        std::vector<std::thread> threads;
        for (int i = 0; i < 8; i++) {
            threads.emplace_back([&html, &total_bytes]() {
                XMConfig cfg = {1, 256, 16.0f, nullptr, nullptr, XM_LOG_ERROR};
                XMParser* p = xmarkup_create(&cfg);
                XMResult* r = xmarkup_parse(p, html.c_str(), html.size());
                xmarkup_result_free(r);
                xmarkup_destroy(p);
                total_bytes += html.size();
            });
        }
        for (auto& t : threads) t.join();
        state.SetBytesProcessed(total_bytes.load());
    }
}
BENCHMARK(BM_Concurrent_8Threads);

static void BM_Concurrent_16Threads(benchmark::State& state) {
    auto html = HtmlGenerator::mixed(50 * 1024);
    for (auto _ : state) {
        std::atomic<uint64_t> total_bytes{0};
        std::vector<std::thread> threads;
        for (int i = 0; i < 16; i++) {
            threads.emplace_back([&html, &total_bytes]() {
                XMConfig cfg = {1, 256, 16.0f, nullptr, nullptr, XM_LOG_ERROR};
                XMParser* p = xmarkup_create(&cfg);
                XMResult* r = xmarkup_parse(p, html.c_str(), html.size());
                xmarkup_result_free(r);
                xmarkup_destroy(p);
                total_bytes += html.size();
            });
        }
        for (auto& t : threads) t.join();
        state.SetBytesProcessed(total_bytes.load());
    }
}
BENCHMARK(BM_Concurrent_16Threads);
```

- [ ] **步骤 4：追加特殊场景 benchmark（3 个）**

```cpp
// ============================================================
// 4.5 特殊场景（3 个）
// ============================================================

static void BM_DeepNesting_1000(benchmark::State& state) {
    auto html = HtmlGenerator::deep_nesting(1000);
    XMConfig cfg = {1, 256, 16.0f, nullptr, nullptr, XM_LOG_ERROR};
    for (auto _ : state) {
        XMParser* p = xmarkup_create(&cfg);
        XMResult* r = xmarkup_parse(p, html.c_str(), html.size());
        benchmark::DoNotOptimize(r);
        xmarkup_result_free(r);
        xmarkup_destroy(p);
    }
}
BENCHMARK(BM_DeepNesting_1000);

static void BM_WideTable_100x20(benchmark::State& state) {
    auto html = HtmlGenerator::wide_table(100, 20);
    XMConfig cfg = {1, 256, 16.0f, nullptr, nullptr, XM_LOG_ERROR};
    for (auto _ : state) {
        XMParser* p = xmarkup_create(&cfg);
        XMResult* r = xmarkup_parse(p, html.c_str(), html.size());
        benchmark::DoNotOptimize(r);
        xmarkup_result_free(r);
        xmarkup_destroy(p);
    }
}
BENCHMARK(BM_WideTable_100x20);

static void BM_AdoptionAgency_1000(benchmark::State& state) {
    auto html = HtmlGenerator::adoption_pattern(1000);
    XMConfig cfg = {1, 256, 16.0f, nullptr, nullptr, XM_LOG_ERROR};
    for (auto _ : state) {
        XMParser* p = xmarkup_create(&cfg);
        XMResult* r = xmarkup_parse(p, html.c_str(), html.size());
        benchmark::DoNotOptimize(r);
        xmarkup_result_free(r);
        xmarkup_destroy(p);
    }
}
BENCHMARK(BM_AdoptionAgency_1000);
```

- [ ] **步骤 5：编译并运行全部 18 个 benchmark**

运行：`cd /Users/arcangelw/GitHub/XMarkup/build-bench && cmake --build . 2>&1 | tail -5 && ./tests/xmarkup_bench 2>&1`
预期：输出 18 行 benchmark 结果

- [ ] **步骤 6：Commit**

```bash
cd /Users/arcangelw/GitHub/XMarkup
git add tests/benchmark.cpp
git commit -m "feat(bench): 18 个 benchmark case — 分阶段 + 内存 + 并发 + 特殊场景"
```

---

### 任务 6：GoogleTest 性能回归测试（3 个 case）

**文件：**
- 修改：`tests/test_api.cpp`

- [ ] **步骤 1：在 test_api.cpp 末尾追加 3 个回归测试**

在最后一个 `TEST_F` 之后追加：

```cpp
// === 性能回归测试 ===

TEST_F(APITest, PerfRegression_50KB_Under15ms) {
    // 生成 50KB 混合 HTML
    std::string html;
    html.reserve(50000);
    const char* paragraph = "<p><b style=\"color:#ff0000\">Bold</b><i>Italic</i></p>";
    size_t par_len = std::char_traits<char>::length(paragraph);
    while (html.size() + par_len <= 50000) {
        html += paragraph;
    }

    auto start = std::chrono::high_resolution_clock::now();
    auto* r = xmarkup_parse(parser_, html.c_str(), html.size());
    auto end = std::chrono::high_resolution_clock::now();

    ASSERT_NE(r, nullptr);
    EXPECT_EQ(r->error, XM_OK);
    xmarkup_result_free(r);

    auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count();
    EXPECT_LT(ms, 15) << "50KB 混合 HTML 解析耗时 " << ms << "ms，超出 15ms 基线";
}

TEST_F(APITest, PerfRegression_100KB_ScaleLinear) {
    // 生成 50KB 和 100KB HTML，验证线性缩放
    auto gen_50kb = [&]() {
        std::string html;
        html.reserve(50000);
        const char* paragraph = "<p><b style=\"color:#ff0000\">Bold</b><i>Italic</i></p>";
        size_t par_len = std::char_traits<char>::length(paragraph);
        while (html.size() + par_len <= 50000) html += paragraph;
        return html;
    };

    auto html_50 = gen_50kb();
    auto html_100 = gen_50kb() + gen_50kb();

    auto time_parse = [&](const std::string& h) -> double {
        auto s = std::chrono::high_resolution_clock::now();
        auto* r = xmarkup_parse(parser_, h.c_str(), h.size());
        auto e = std::chrono::high_resolution_clock::now();
        xmarkup_result_free(r);
        return std::chrono::duration_cast<std::chrono::microseconds>(e - s).count() / 1000.0;
    };

    double ms_50 = time_parse(html_50);
    double ms_100 = time_parse(html_100);

    // 100KB 耗时不应超过 50KB 的 2.5 倍（允许一定波动）
    EXPECT_LT(ms_100, ms_50 * 2.5)
        << "100KB (" << ms_100 << "ms) vs 50KB (" << ms_50 << "ms)，非线性缩放";
}

TEST_F(APITest, PerfRegression_DeepNesting_NoExplosion) {
    std::string html;
    for (int i = 0; i < 1000; i++) html += "<div>";
    html += "text";

    auto start = std::chrono::high_resolution_clock::now();
    auto* r = xmarkup_parse(parser_, html.c_str(), html.size());
    auto end = std::chrono::high_resolution_clock::now();

    ASSERT_NE(r, nullptr);
    EXPECT_NE(r->text, nullptr);
    xmarkup_result_free(r);

    auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count();
    EXPECT_LT(ms, 5) << "1000 层嵌套解析耗时 " << ms << "ms，超出 5ms 基线";
}
```

- [ ] **步骤 2：构建并运行全部测试**

运行：`cd /Users/arcangelw/GitHub/XMarkup/build && cmake --build . 2>&1 | tail -5 && ./tests/test_api --gtest_filter=*Perf* 2>&1`
预期：3 个测试全部 PASSED

- [ ] **步骤 3：运行全量测试确认无回归**

运行：`cd /Users/arcangelw/GitHub/XMarkup/build && for t in tests/test_*; do [[ -x "$t" ]] && ./$t --gtest_brief=1; done 2>/dev/null`
预期：全部通过

- [ ] **步骤 4：Commit**

```bash
cd /Users/arcangelw/GitHub/XMarkup
git add tests/test_api.cpp
git commit -m "test: 3 个性能回归 case — 50KB<15ms + 线性缩放 + 深层嵌套<5ms"
```

---

### 任务 7：最终验证

**文件：** 无变更

- [ ] **步骤 1：普通构建全量测试**

运行：`cd /Users/arcangelw/GitHub/XMarkup/build && cmake .. && cmake --build . && for t in tests/test_*; do [[ -x "$t" ]] && ./$t --gtest_brief=1; done 2>/dev/null`
预期：全部通过（含新增 3 个回归 case）

- [ ] **步骤 2：Benchmark 构建全量运行**

运行：`cd /Users/arcangelw/GitHub/XMarkup/build-bench && cmake .. -DXMARKUP_BUILD_BENCHMARKS=ON && cmake --build . && ./tests/xmarkup_bench 2>&1`
预期：18 行 benchmark 结果

- [ ] **步骤 3：ASAN 验证回归测试**

运行：`cd /Users/arcangelw/GitHub/XMarkup && cd build-asan && cmake .. -DCMAKE_BUILD_TYPE=Debug -DCMAKE_CXX_FLAGS="-fsanitize=address,undefined -fno-omit-frame-pointer" -DCMAKE_C_FLAGS="-fsanitize=address,undefined -fno-omit-frame-pointer" -DCMAKE_EXE_LINKER_FLAGS="-fsanitize=address,undefined" && cmake --build . && for t in tests/test_*; do [[ -x "$t" ]] && ./$t --gtest_brief=1; done 2>/dev/null`
预期：全部通过，ASAN 无泄漏
