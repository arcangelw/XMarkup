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
    if (!result) return;
    delete result;
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
