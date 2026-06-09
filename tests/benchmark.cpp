#include <benchmark/benchmark.h>
#include "xmarkup/xmarkup.h"
#include "bench_helpers.h"

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

BENCHMARK_MAIN();
