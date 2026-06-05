#include "style_resolver.h"

namespace xmarkup {

StyleResolver::StyleResolver(uint16_t base_font_size)
    : base_font_size_(base_font_size) {
    (void)base_font_size_;
    (void)byte_offset_;
}

FlattenResult StyleResolver::resolve(const ASTNode&) { return {}; }

void StyleResolver::dfs(const ASTNode&, bool) {}
int StyleResolver::map_tag(std::string_view) const { return 0; }
void StyleResolver::parse_inline_style(std::string_view) {}
void StyleResolver::extract_attribute_value(std::string_view, const char*,
                                            std::string&) const {}
std::string StyleResolver::normalize_color(std::string_view) const { return {}; }
std::string StyleResolver::normalize_font_size(std::string_view) const { return {}; }
std::string StyleResolver::normalize_font_weight(std::string_view) const { return {}; }

} // namespace xmarkup
