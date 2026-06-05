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
    include(GoogleTest)
    gtest_discover_tests(${test_name})
endforeach()
