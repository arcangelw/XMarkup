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

    last_error = XM_OK;
    owned_text_.clear();
    owned_spans_.clear();
    owned_values_.clear();

    // 1. 词法分析
    std::string_view html_view(html, length);
    Tokenizer tokenizer(html_view);
    std::vector<Token> tokens;
    while (tokenizer.has_next()) {
        tokens.push_back(tokenizer.next());
    }

    // 2. 构建AST
    TreeBuilder tree_builder(config.max_nesting_depth, config.enable_autocorrect);
    ASTNode ast = tree_builder.build(tokens);

    // 3. 样式解析 + 实体解码
    StyleResolver style_resolver(config.base_font_size);
    FlattenResult flat = style_resolver.resolve(ast);

    // 4. UTF-16 索引映射
    UTF16Indexer indexer;
    indexer.build(flat.text);

    // 5. 组装 XMResult
    auto* result = new (std::nothrow) XMResult();
    if (!result) {
        last_error = XM_ERR_ALLOC_FAILED;
        return nullptr;
    }

    result->error = XM_OK;
    result->span_count = 0;
    result->spans = nullptr;
    result->text = nullptr;
    result->text_len = 0;

    // 拷贝文本
    if (!flat.text.empty()) {
        owned_text_ = std::move(flat.text);
        result->text = owned_text_.c_str();
        result->text_len = static_cast<uint32_t>(owned_text_.size());
    }

    // 转换 InternalSpan → XMSpan（byte offset → UTF-16 index）
    if (!flat.spans.empty()) {
        owned_values_.reserve(flat.spans.size());
        owned_spans_.resize(flat.spans.size());

        for (size_t i = 0; i < flat.spans.size(); i++) {
            const auto& src = flat.spans[i];
            auto& dst = owned_spans_[i];

            dst.range.start = indexer.byte_to_utf16(src.byte_start);
            dst.range.end = indexer.byte_to_utf16(src.byte_end);
            dst.tag = static_cast<XMTagType>(src.tag);
            dst.style = static_cast<XMStyleType>(src.style);

            if (!src.value.empty()) {
                owned_values_.push_back(src.value);
                dst.value = owned_values_.back().c_str();
                dst.value_len = static_cast<uint32_t>(owned_values_.back().size());
            } else {
                dst.value = nullptr;
                dst.value_len = 0;
            }
        }

        result->spans = owned_spans_.data();
        result->span_count = static_cast<uint32_t>(owned_spans_.size());
    }

    return result;
}

} // namespace xmarkup
