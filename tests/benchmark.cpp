#include <benchmark/benchmark.h>
#include "xmarkup/xmarkup.h"
#include "bench_helpers.h"
#include <thread>
#include <atomic>
#include <vector>
#include <cstdio>

// ============================================================
// 4.1 吞吐量基准（6 个）
// ============================================================

#define BENCH_THROUGHPUT(name, size_bytes) \
static void name(benchmark::State& state) { \
    auto html = HtmlGenerator::mixed(size_bytes); \
    XMConfig cfg = {1, 256, 16.0f, nullptr, nullptr, XM_LOG_ERROR}; \
    for (auto _ : state) { \
        XMParser* p = xmarkup_create(&cfg); \
        XMResult* r = xmarkup_parse(p, html.c_str(), html.size()); \
        benchmark::DoNotOptimize(r); \
        xmarkup_result_free(r); \
        xmarkup_destroy(p); \
    } \
    state.SetBytesProcessed(state.iterations() * html.size()); \
} \
BENCHMARK(name);

BENCH_THROUGHPUT(BM_Throughput_1KB,   1 * 1024)
BENCH_THROUGHPUT(BM_Throughput_10KB,  10 * 1024)
BENCH_THROUGHPUT(BM_Throughput_50KB,  50 * 1024)
BENCH_THROUGHPUT(BM_Throughput_100KB, 100 * 1024)
BENCH_THROUGHPUT(BM_Throughput_500KB, 500 * 1024)
BENCH_THROUGHPUT(BM_Throughput_1MB,   1024 * 1024)

// ============================================================
// 4.2 分阶段耗时（4 个）
// ============================================================

#define BENCH_STAGES(name, gen_expr) \
static void name(benchmark::State& state) { \
    auto html = gen_expr; \
    XMConfig cfg = {1, 256, 16.0f, nullptr, nullptr, XM_LOG_ERROR}; \
    StageTimer last{}; \
    for (auto _ : state) { \
        last = StageTimer::measure(html.c_str(), html.size(), cfg); \
        benchmark::DoNotOptimize(&last); \
    } \
    char label[128]; \
    uint64_t tot = last.total_us ? last.total_us : 1; \
    snprintf(label, sizeof(label), \
        "tok=%llu%% tree=%llu%% style=%llu%% utf16=%llu%%", \
        (unsigned long long)(last.tokenizer_us * 100 / tot), \
        (unsigned long long)(last.tree_builder_us * 100 / tot), \
        (unsigned long long)(last.style_resolver_us * 100 / tot), \
        (unsigned long long)(last.utf16_indexer_us * 100 / tot)); \
    state.SetLabel(label); \
} \
BENCHMARK(name);

BENCH_STAGES(BM_StageBreakdown_50KB,         HtmlGenerator::mixed(50 * 1024))
BENCH_STAGES(BM_StageBreakdown_HeavyTags,    HtmlGenerator::heavy_tags(50 * 1024))
BENCH_STAGES(BM_StageBreakdown_HeavyStyle,   HtmlGenerator::heavy_style(50 * 1024))
BENCH_STAGES(BM_StageBreakdown_Multilingual, HtmlGenerator::mixed_multilingual(50 * 1024))

// ============================================================
// 4.3 内存基准（3 个）
// ============================================================

#define BENCH_MEMORY(name, size_bytes) \
static void name(benchmark::State& state) { \
    auto html = HtmlGenerator::mixed(size_bytes); \
    XMConfig cfg = {1, 256, 16.0f, nullptr, nullptr, XM_LOG_ERROR}; \
    size_t max_delta = 0; \
    for (auto _ : state) { \
        auto mt = MemoryTracker::measure_parsing(html.c_str(), html.size(), cfg); \
        if (mt.delta_rss_kb > max_delta) max_delta = mt.delta_rss_kb; \
    } \
    char label[64]; \
    snprintf(label, sizeof(label), "rss_delta=%zuKB (%.1fx input)", \
        max_delta, max_delta * 1024.0 / html.size()); \
    state.SetLabel(label); \
} \
BENCHMARK(name);

BENCH_MEMORY(BM_Memory_50KB,  50 * 1024)
BENCH_MEMORY(BM_Memory_500KB, 500 * 1024)
BENCH_MEMORY(BM_Memory_1MB,   1024 * 1024)

// ============================================================
// 4.4 并发性能（2 个）
// ============================================================

#define BENCH_CONCURRENT(name, thread_count) \
static void name(benchmark::State& state) { \
    auto html = HtmlGenerator::mixed(50 * 1024); \
    for (auto _ : state) { \
        std::atomic<uint64_t> total_bytes{0}; \
        std::vector<std::thread> threads; \
        for (int i = 0; i < thread_count; i++) { \
            threads.emplace_back([&html, &total_bytes]() { \
                XMConfig cfg = {1, 256, 16.0f, nullptr, nullptr, XM_LOG_ERROR}; \
                XMParser* p = xmarkup_create(&cfg); \
                XMResult* r = xmarkup_parse(p, html.c_str(), html.size()); \
                xmarkup_result_free(r); \
                xmarkup_destroy(p); \
                total_bytes += html.size(); \
            }); \
        } \
        for (auto& t : threads) t.join(); \
        state.SetBytesProcessed(total_bytes.load()); \
    } \
} \
BENCHMARK(name);

BENCH_CONCURRENT(BM_Concurrent_8Threads,  8)
BENCH_CONCURRENT(BM_Concurrent_16Threads, 16)

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

// ============================================================
// 4.6 新增基准场景
// ============================================================

static void BM_EntityHeavy_50KB(benchmark::State& state) {
    auto html = HtmlGenerator::heavy_entities(50 * 1024);
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
BENCHMARK(BM_EntityHeavy_50KB);

static void BM_SmallInput_Latency(benchmark::State& state) {
    auto html = HtmlGenerator::tiny_paragraph();
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
BENCHMARK(BM_SmallInput_Latency);

static void BM_PureText_50KB(benchmark::State& state) {
    auto html = HtmlGenerator::pure_text(50 * 1024);
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
BENCHMARK(BM_PureText_50KB);

static void BM_HeavyTags_50KB(benchmark::State& state) {
    auto html = HtmlGenerator::heavy_tags(50 * 1024);
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
BENCHMARK(BM_HeavyTags_50KB);

static void BM_AdoptionAgency_10000(benchmark::State& state) {
    auto html = HtmlGenerator::adoption_pattern(10000);
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
BENCHMARK(BM_AdoptionAgency_10000);

BENCHMARK_MAIN();
