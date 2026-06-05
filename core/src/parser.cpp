#include "parser.h"
#include "tokenizer.h"
#include "tree_builder.h"
#include "style_resolver.h"
#include "utf16_indexer.h"
#include <cstring>
#include <cstdlib>

namespace xmarkup {

XMResult* ParserInternal::parse(const char* html, size_t length) {
    if (!html && length > 0) {
        last_error = XM_ERR_NULL_INPUT;
        return nullptr;
    }

    // 占位实现，后续任务完善
    owned_text_.clear();
    owned_spans_.clear();
    owned_values_.clear();

    auto* result = new (std::nothrow) XMResult();
    if (!result) {
        last_error = XM_ERR_ALLOC_FAILED;
        return nullptr;
    }

    result->error = XM_OK;
    result->text = nullptr;
    result->text_len = 0;
    result->spans = nullptr;
    result->span_count = 0;
    last_error = XM_OK;
    return result;
}

} // namespace xmarkup
