#include "tree_builder.h"

namespace xmarkup {

TreeBuilder::TreeBuilder(uint16_t max_depth, bool autocorrect)
    : max_depth_(max_depth), autocorrect_(autocorrect) {
    root_.type = ASTNode::ROOT;
    (void)max_depth_;
    (void)autocorrect_;
}

ASTNode TreeBuilder::build(const std::vector<Token>&) { return root_; }

bool TreeBuilder::is_void_element(std::string_view) const { return false; }
void TreeBuilder::handle_start_tag(const Token&) {}
void TreeBuilder::handle_end_tag(const Token&) {}
void TreeBuilder::handle_self_closing(const Token&) {}

} // namespace xmarkup
