#pragma once

#include "tree_builder.h"
#include "xmarkup/xmarkup.h"
#include <vector>
#include <string>
#include <string_view>

namespace xmarkup {

struct InternalSpan {
    uint32_t    byte_start = 0;
    uint32_t    byte_end = 0;
    int         tag = 0;
    int         style = 0;
    std::string value;
};

struct FlattenResult {
    std::string               text;
    std::vector<InternalSpan> spans;
};

class StyleResolver {
public:
    explicit StyleResolver(uint16_t base_font_size = 16);
    FlattenResult resolve(const ASTNode& root);

private:
    void dfs(const ASTNode& node, bool inside_pre);
    int  map_tag(std::string_view tag_name) const;
    void parse_inline_style(std::string_view style_str);
    void add_style_spans(const std::string& style_str, uint32_t start, uint32_t end);
    void extract_attribute_value(std::string_view attrs, const char* attr_name,
                                 std::string& out_value) const;
    std::string normalize_color(std::string_view value) const;
    std::string normalize_font_size(std::string_view value) const;
    std::string normalize_font_weight(std::string_view value) const;

    uint16_t base_font_size_;
    FlattenResult result_;
    std::vector<std::string_view> parent_stack_;
    uint32_t byte_offset_ = 0;
};

} // namespace xmarkup
