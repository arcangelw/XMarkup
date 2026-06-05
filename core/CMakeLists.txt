add_library(xmarkup_core STATIC
    src/tokenizer.cpp
    src/tree_builder.cpp
    src/style_resolver.cpp
    src/entity_decoder.cpp
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
