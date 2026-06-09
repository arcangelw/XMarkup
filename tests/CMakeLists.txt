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
    test_entity_decoder
    test_utf16_indexer
    test_api
)
    add_executable(${test_name} ${test_name}.cpp)
    target_link_libraries(${test_name}
        PRIVATE xmarkup_core GTest::gtest_main
    )
    target_include_directories(${test_name}
        PRIVATE ${CMAKE_SOURCE_DIR}/core/src
    )
    include(GoogleTest)
    gtest_discover_tests(${test_name})
endforeach()

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
