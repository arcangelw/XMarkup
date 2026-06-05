#include "parser.h"

extern "C" {

XMParser* xmarkup_create(const XMConfig* config) {
    XMConfig cfg = {1, 256, 16};
    if (config) cfg = *config;
    auto* p = new (std::nothrow) xmarkup::ParserInternal();
    if (!p) return nullptr;
    p->config = cfg;
    p->last_error = XM_OK;
    return reinterpret_cast<XMParser*>(p);
}

void xmarkup_destroy(XMParser* parser) {
    if (parser) delete reinterpret_cast<xmarkup::ParserInternal*>(parser);
}

XMResult* xmarkup_parse(XMParser* parser, const char* html, size_t length) {
    if (!parser) return nullptr;
    auto* p = reinterpret_cast<xmarkup::ParserInternal*>(parser);
    return p->parse(html, length);
}

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

} // extern "C"
