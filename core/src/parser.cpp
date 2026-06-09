#include "parser.h"
#include "tokenizer.h"
#include "tree_builder.h"
#include "style_resolver.h"
#include "utf16_indexer.h"
#include "logger.h"
#include <cstring>
#include <cstdlib>

namespace xmarkup {

/**
 * @brief 执行完整解析管线
 *
 * 管线阶段：
 * 1. 词法分析 —— HTML 字符串 → Token 序列
 * 2. AST 构建 —— Token 序列 → 树形结构
 * 3. 样式解析 —— AST → 扁平文本 + 样式区间（byte offset）
 * 4. UTF-16 映射 —— byte offset → UTF-16 索引
 * 5. 结果组装 —— 内部数据 → XMResult C 结构体
 *
 * 数据流：
 *   html string → [Tokenizer] → tokens → [TreeBuilder] → AST
 *   → [StyleResolver] → FlattenResult{text, spans}
 *   → [UTF16Indexer] → XMResult{text, spans (UTF-16)}
 *
 * 内存管理：
 * - owned_text_ 持有文本数据（XMResult.text 指向 c_str()）
 * - owned_spans_ 持有 span 数组（XMResult.spans 指向 data()）
 * - owned_values_ 持有 value 字符串（XMSpan.value 指向 c_str()）
 * - 每次调用 clear() 上一轮数据，XMResult 指针在下一次 parse 前有效
 */
XMResult* ParserInternal::parse(const char* html, size_t length) {
    // 输入校验
    if (!html && length > 0) {
        last_error = XM_ERR_NULL_INPUT;
        return nullptr;
    }

    last_error = XM_OK;
    // 清空上一轮数据（XMResult 指针自此失效）
    owned_text_.clear();
    owned_spans_.clear();
    owned_values_.clear();

    // 空/null 输入：返回空结果（避免 std::string_view(nullptr, 0) 的 UB）
    if (!html || length == 0) {
        Logger::info("parse start: length=0 (empty)");
        auto* result = new (std::nothrow) XMResult();
        if (!result) {
            last_error = XM_ERR_ALLOC_FAILED;
            return nullptr;
        }
        result->error = XM_OK;
        result->text = "";
        result->text_len = 0;
        result->spans = nullptr;
        result->span_count = 0;
        return result;
    }

    // 阶段 1：词法分析
    Logger::info("parse start: length=%zu", length);
    std::string_view html_view(html, length);
    Tokenizer tokenizer(html_view);
    std::vector<Token> tokens;
    while (tokenizer.has_next()) {
        tokens.push_back(tokenizer.next());
    }

    // 阶段 2：构建 AST
    TreeBuilder tree_builder(config.max_nesting_depth, config.enable_autocorrect);
    ASTNode ast = tree_builder.build(tokens);

    // 阶段 3：样式解析 + 实体解码
    StyleResolver style_resolver(config.base_font_size);
    FlattenResult flat = style_resolver.resolve(ast);

    // 阶段 4：UTF-16 索引映射
    UTF16Indexer indexer;
    indexer.build(flat.text);

    // 阶段 5：组装 XMResult
    auto* result = new (std::nothrow) XMResult();
    if (!result) {
        Logger::error("alloc failed: XMResult");
        last_error = XM_ERR_ALLOC_FAILED;
        return nullptr;
    }

    result->error = XM_OK;
    result->span_count = 0;
    result->spans = nullptr;
    result->text = nullptr;
    result->text_len = 0;

    // 拷贝文本（即使是空字符串也要保证 text 指针非 NULL）
    owned_text_ = std::move(flat.text);
    result->text = owned_text_.c_str();
    result->text_len = static_cast<uint32_t>(owned_text_.size());

    // 转换 InternalSpan → XMSpan（byte offset → UTF-16 索引）
    if (!flat.spans.empty()) {
        owned_values_.reserve(flat.spans.size());
        owned_spans_.resize(flat.spans.size());

        for (size_t i = 0; i < flat.spans.size(); i++) {
            const auto& src = flat.spans[i];
            auto& dst = owned_spans_[i];

            // byte offset → UTF-16 索引
            dst.range.start = indexer.byte_to_utf16(src.byte_start);
            dst.range.end = indexer.byte_to_utf16(src.byte_end);
            dst.tag = static_cast<XMTagType>(src.tag);
            dst.style = static_cast<XMStyleType>(src.style);

            // value 字符串需要持久化（string_view → owned string）
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

    Logger::info("parse done: text_len=%u, span_count=%u", result->text_len, result->span_count);
    return result;
}

} // namespace xmarkup
