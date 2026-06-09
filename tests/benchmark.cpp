#include <benchmark/benchmark.h>
#include "xmarkup/xmarkup.h"
#include "bench_helpers.h"

// 验证 HtmlGenerator 编译和运行
static void BM_HtmlGeneratorCheck(benchmark::State& state) {
    auto html = HtmlGenerator::mixed(1024);
    for (auto _ : state) {
        auto copy = html;
        benchmark::DoNotOptimize(copy);
    }
}
BENCHMARK(BM_HtmlGeneratorCheck);

BENCHMARK_MAIN();
