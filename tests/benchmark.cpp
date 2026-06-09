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
