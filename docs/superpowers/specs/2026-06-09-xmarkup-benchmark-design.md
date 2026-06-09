# XMarkup 性能测试设计规格

> 日期：2026-06-09
> 状态：已批准

---

## 1. 目标

为 XMarkup C++ 核心引擎建立系统化的性能测试体系，同时满足两个目标：

- **CI 回归保护** — 在 GoogleTest 中设置性能阈值，防止未来改动引入性能退化
- **详细 Benchmark 报告** — 使用 Google Benchmark 精确测量各管线阶段耗时、内存、并发性能

---

## 2. 架构：Google Benchmark + GoogleTest 混合

```
tests/
├── bench_helpers.h      # 共享辅助工具（HTML 生成器 + 分阶段计时器 + 内存追踪）
├── benchmark.cpp         # Google Benchmark 入口，18 个 benchmark case
├── test_api.cpp          # 现有 GoogleTest（补充 3 个回归 case）
└── CMakeLists.txt        # 新增 xmarkup_bench target
```

**运行方式：**

| 命令 | 运行内容 | 用途 |
|------|---------|------|
| `ctest` | GoogleTest（含回归测试） | CI 验证，快速 fail |
| `./tests/xmarkup_bench` | Google Benchmark 18 个 case | 详细性能分析 |

---

## 3. bench_helpers.h — 共享辅助工具

### 3.1 HTML 生成器

```cpp
struct HtmlGenerator {
    /// 生成指定大小的混合 HTML（段落+加粗+斜体+链接+列表+表格+CSS样式）
    static std::string mixed(size_t target_bytes);

    /// 生成特定模式的 HTML（用于隔离某个管线阶段的瓶颈）
    static std::string pure_text(size_t target_bytes);      // 纯文本，无标签
    static std::string heavy_tags(size_t target_bytes);     // 密集嵌套标签
    static std::string heavy_style(size_t target_bytes);    // 大量 CSS inline style
    static std::string deep_nesting(int depth);             // 深层嵌套
    static std::string wide_table(int rows, int cols);      // 大表格
    static std::string mixed_multilingual(size_t target_bytes); // 中英日韩Emoji混合
};
```

**生成策略：** 循环填充模板段落直到达到目标字节数，最后一个段落截断到精确大小。

**模板段落示例：**
```html
<p><b style="color:#ff0000">Bold text 12345</b><i>Italic</i></p>
<ul><li>Item A</li><li>Item B</li></ul>
<a href="https://example.com">Link</a>
<table><tr><td>Cell</td></tr></table>
```

### 3.2 分阶段计时器

```cpp
struct StageTimer {
    uint64_t tokenizer_us;       // 词法分析耗时（微秒）
    uint64_t tree_builder_us;    // AST 构建耗时（微秒）
    uint64_t style_resolver_us;  // 样式解析耗时（微秒）
    uint64_t utf16_indexer_us;   // UTF-16 映射耗时（微秒）
    uint64_t total_us;           // 总耗时（微秒）

    /// 对解析器做一次完整分阶段计时
    /// 复制 ParserInternal::parse() 逻辑，在各阶段之间插入计时点
    /// 不修改核心引擎代码，在 benchmark 侧直接调用各模块
    static StageTimer measure(const char* html, size_t length, const XMConfig& cfg);
};
```

**实现要点：** 直接 include 内部头文件（`tokenizer.h`、`tree_builder.h`、`style_resolver.h`、`utf16_indexer.h`），依次调用各阶段并在阶段间插入 `chrono::high_resolution_clock` 计时点。

### 3.3 内存追踪器

```cpp
struct MemoryTracker {
    size_t peak_rss_kb;    // 峰值 RSS（resident set size）
    size_t delta_rss_kb;   // 解析前后 RSS 差值

    static MemoryTracker snapshot();
    static MemoryTracker measure_parsing(const char* html, size_t length, const XMConfig& cfg);
};
```

**实现方式：**
- macOS：`#include <mach/mach.h>` → `task_info(TASK_BASIC_INFO)` 获取 `resident_size`
- Linux：读 `/proc/self/status` 的 `VmRSS` 行
- 通过前后快照差值计算解析过程内存增量

---

## 4. benchmark.cpp — 18 个 Benchmark Case

### 4.1 吞吐量基准（6 个）

| Case | 输入 | 指标 |
|------|------|------|
| `BM_Throughput_1KB` | 1 KB mixed | 总耗时 + MB/s |
| `BM_Throughput_10KB` | 10 KB mixed | 同上 |
| `BM_Throughput_50KB` | 50 KB mixed | 同上 |
| `BM_Throughput_100KB` | 100 KB mixed | 同上 |
| `BM_Throughput_500KB` | 500 KB mixed | 同上 |
| `BM_Throughput_1MB` | 1 MB mixed | 同上 |

**实现模式：**
```cpp
static void BM_Throughput_50KB(benchmark::State& state) {
    auto html = HtmlGenerator::mixed(50 * 1024);
    XMConfig cfg = {1, 256, 16.0f, nullptr, nullptr, XM_LOG_ERROR};
    for (auto _ : state) {
        XMParser* p = xmarkup_create(&cfg);
        XMResult* r = xmarkup_parse(p, html.c_str(), html.size());
        xmarkup_result_free(r);
        xmarkup_destroy(p);
    }
    state.SetBytesProcessed(state.iterations() * html.size());
    state.SetLabel("50KB mixed HTML");
}
BENCHMARK(BM_Throughput_50KB);
```

### 4.2 分阶段耗时（4 个）

| Case | 输入 | 目的 |
|------|------|------|
| `BM_StageBreakdown_50KB` | 50KB mixed | 输出四阶段耗时占比 |
| `BM_StageBreakdown_HeavyTags` | heavy_tags 50KB | 重点看 TreeBuilder |
| `BM_StageBreakdown_HeavyStyle` | heavy_style 50KB | 重点看 StyleResolver |
| `BM_StageBreakdown_Multilingual` | mixed_multilingual 50KB | 重点看 UTF16Indexer |

**输出格式：** 使用 `benchmark::State::SetLabel()` 附加各阶段百分比。

**实现模式：**
```cpp
static void BM_StageBreakdown_50KB(benchmark::State& state) {
    auto html = HtmlGenerator::mixed(50 * 1024);
    XMConfig cfg = {1, 256, 16.0f, nullptr, nullptr, XM_LOG_ERROR};
    for (auto _ : state) {
        auto t = StageTimer::measure(html.c_str(), html.size(), cfg);
        // Google Benchmark 不支持每次迭代输出多指标，
        // 用 SetItemsProcessed 标记总调用次数
    }
    // 最后一次测量的分阶段结果通过 label 输出
    auto final = StageTimer::measure(html.c_str(), html.size(), cfg);
    char label[128];
    snprintf(label, sizeof(label), "token=%lu%% tree=%lu%% style=%lu%% utf16=%lu%%",
        final.tokenizer_us * 100 / final.total_us,
        final.tree_builder_us * 100 / final.total_us,
        final.style_resolver_us * 100 / final.total_us,
        final.utf16_indexer_us * 100 / final.total_us);
    state.SetLabel(label);
}
BENCHMARK(BM_StageBreakdown_50KB);
```

### 4.3 内存基准（3 个）

| Case | 输入 | 指标 |
|------|------|------|
| `BM_Memory_50KB` | 50KB mixed | 峰值 RSS / 输入大小比值 |
| `BM_Memory_500KB` | 500KB mixed | 同上 |
| `BM_Memory_1MB` | 1MB mixed | 同上 |

**实现模式：** 每次迭代前后 `MemoryTracker::snapshot()` 差值，取所有迭代的最大值。

### 4.4 并发性能（2 个）

| Case | 目的 |
|------|------|
| `BM_Concurrent_8Threads` | 8 线程各自解析 50KB，测总吞吐量 |
| `BM_Concurrent_16Threads` | 16 线程，验证线程安全下的性能衰减 |

**实现模式：** 主线程用 `std::thread` 启动 N 个线程，每个线程循环解析，用 `std::atomic` 累计完成次数，测量总吞吐量。

```cpp
static void BM_Concurrent_8Threads(benchmark::State& state) {
    auto html = HtmlGenerator::mixed(50 * 1024);
    for (auto _ : state) {
        std::atomic<uint64_t> total_bytes{0};
        std::vector<std::thread> threads;
        constexpr int N = 8;
        for (int i = 0; i < N; i++) {
            threads.emplace_back([&]() {
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
BENCHMARK(BM_Concurrent_8Threads)->Iterations(100);
```

### 4.5 特殊场景（3 个）

| Case | 输入 | 目的 |
|------|------|------|
| `BM_DeepNesting_1000` | 1000 层 `<div>` | 验证栈性能 |
| `BM_WideTable_100x20` | 100 行 × 20 列表格 | 验证隐式关闭在大规模表格中的开销 |
| `BM_AdoptionAgency_1000` | 1000 个 `<b>text<p>para` 模式 | 验证 adoption agency 性能 |

**Adoption Agency 测试模式：**
```cpp
// 生成 1000 个 <b>text<p>para 模式
static std::string adoption_pattern(int count) {
    std::string html = "<div>";
    for (int i = 0; i < count; i++) {
        html += "<b>text<p>para</p>";
    }
    html += "</div>";
    return html;
}
```

---

## 5. GoogleTest 回归测试补充

在现有 `test_api.cpp` 中新增 3 个 case：

| Case | 阈值 | 目的 |
|------|------|------|
| `PerfRegression_50KB_Under15ms` | 50KB mixed < 15ms | 核心性能基线 |
| `PerfRegression_100KB_ScaleLinear` | 100KB 耗时 < 50KB × 2.5 | 验证线性缩放 |
| `PerfRegression_DeepNesting_NoExplosion` | 1000 层嵌套 < 5ms | 验证深度限制不引入性能问题 |

现有 `Stress50KB` 保留不动（作为宽松烟雾测试）。

---

## 6. CMake 集成

```cmake
# tests/CMakeLists.txt 追加内容

# Google Benchmark（可选构建）
option(XMARKUP_BUILD_BENCHMARKS "Build performance benchmarks" OFF)
if(XMARKUP_BUILD_BENCHMARKS)
    FetchContent_Declare(
        googlebench
        GIT_REPOSITORY https://github.com/google/benchmark.git
        GIT_TAG        v1.8.3
    )
    set(BENCHMARK_ENABLE_TESTING OFF CACHE BOOL "" FORCE)
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

**关键设计：** `XMARKUP_BUILD_BENCHMARKS` 默认 OFF，CI 不构建 benchmark。需要时 `-DXMARKUP_BUILD_BENCHMARKS=ON` 手动开启。

---

## 7. 预期输出示例

```bash
$ cmake -B build -DXMARKUP_BUILD_BENCHMARKS=ON && cmake --build build
$ ./build/tests/xmarkup_bench

------------------------------------------------------------------------------
Benchmark                                    Time       CPU   Iterations
------------------------------------------------------------------------------
BM_Throughput_1KB                         123 us    122 us       11382  8.1234MB/s
BM_Throughput_10KB                        891 us    889 us        1572  11.234MB/s
BM_Throughput_50KB                       4230 us   4218 us         331  11.789MB/s
BM_Throughput_100KB                     8520 us   8501 us         164  11.765MB/s
BM_Throughput_500KB                   42100 us  41987 us          33  11.834MB/s
BM_Throughput_1MB                    84300 us  84100 us          17  11.819MB/s
BM_StageBreakdown_50KB                  4310 us   4298 us         325  token=15% tree=12% style=62% utf16=11%
BM_StageBreakdown_HeavyTags             5100 us   5088 us         275  token=14% tree=45% style=28% utf16=13%
BM_StageBreakdown_HeavyStyle            7800 us   7789 us         180  token=8% tree=7% style=75% utf16=10%
BM_StageBreakdown_Multilingual          4500 us   4488 us         312  token=18% tree=14% style=45% utf16=23%
BM_Memory_50KB                         4200 us   4190 us         333  rss_delta=156KB (3.1x input)
BM_Memory_500KB                       39800 us  39700 us          35  rss_delta=1580KB (3.2x input)
BM_Memory_1MB                        79500 us  79300 us          18  rss_delta=3150KB (3.1x input)
BM_Concurrent_8Threads                5800 us   5780 us         243  69.234MB/s
BM_Concurrent_16Threads              11200 us  11100 us         126  71.567MB/s
BM_DeepNesting_1000                    310 us    308 us        4532
BM_WideTable_100x20                   2800 us   2790 us         501
BM_AdoptionAgency_1000                 890 us    888 us        1578
```
