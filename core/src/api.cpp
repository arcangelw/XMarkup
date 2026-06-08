#include "parser.h"

// 默认解析器配置
static constexpr uint8_t  kDefaultAutocorrect = 1;
static constexpr uint16_t kDefaultMaxNestingDepth = 256;
static constexpr float    kDefaultBaseFontSize = 16.0f;

extern "C" {

/**
 * @brief 创建解析器实例
 *
 * 分配 ParserInternal 并初始化配置。config 为 NULL 时使用默认值。
 * 使用 std::nothrow 避免异常，内存不足时返回 NULL。
 */
XMParser* xmarkup_create(const XMConfig* config) {
    XMConfig cfg = {kDefaultAutocorrect, kDefaultMaxNestingDepth, kDefaultBaseFontSize};
    if (config) cfg = *config;
    auto* p = new (std::nothrow) xmarkup::ParserInternal();
    if (!p) return nullptr;
    p->config = cfg;
    p->last_error = XM_OK;
    return reinterpret_cast<XMParser*>(p);
}

/**
 * @brief 销毁解析器
 *
 * 释放 ParserInternal 及其所有内部数据（owned_text_, owned_spans_, owned_values_）。
 * 销毁后所有由此解析器产出的 XMResult 中的 text/spans 指针将悬空。
 */
void xmarkup_destroy(XMParser* parser) {
    if (parser) delete reinterpret_cast<xmarkup::ParserInternal*>(parser);
}

/**
 * @brief 执行解析
 *
 * 将 C API 的不透明句柄转换为 ParserInternal 并调用其 parse 方法。
 */
XMResult* xmarkup_parse(XMParser* parser, const char* html, size_t length) {
    if (!parser) return nullptr;
    auto* p = reinterpret_cast<xmarkup::ParserInternal*>(parser);
    return p->parse(html, length);
}

/**
 * @brief 释放解析结果
 *
 * XMResult 中的 text/spans/value 指针由 ParserInternal 的 owned_* 成员管理，
 * 此处仅释放 XMResult 结构体本身。
 */
void xmarkup_result_free(XMResult* result) {
    // XMResult 中的 text/spans/value 指针由 ParserInternal 的 owned_* 成员管理。
    // 调用 xmarkup_parse 会覆盖上一次的数据，所以只需 delete result 本身。
    // 注意：result 的指针在 ParserInternal 存活期间有效。
    // 为安全起见，此处采用拷贝语义——result 拥有自己的数据副本。
    // 但当前设计中 result 的 text/spans 指向 ParserInternal 内部数据，
    // 所以 result 本身只需 delete（内部数据随 ParserInternal 生命周期管理）。
    if (result) delete result;
}

XMError xmarkup_last_error(XMParser* parser) {
    if (!parser) return XM_ERR_NULL_PARSER;
    return reinterpret_cast<xmarkup::ParserInternal*>(parser)->last_error;
}

const char* xmarkup_error_string(XMError error) {
    switch (error) {
        case XM_OK:                   return "Success";
        case XM_ERR_NULL_PARSER:      return "Parser is NULL";
        case XM_ERR_NULL_INPUT:       return "Input HTML is NULL";
        case XM_ERR_NESTING_OVERFLOW: return "Nesting depth overflow, truncated";
        case XM_ERR_ALLOC_FAILED:     return "Memory allocation failed";
        default:                      return "Unknown error";
    }
}

const char* xmarkup_version(void) {
    return "0.1.0";
}

} // extern "C"
