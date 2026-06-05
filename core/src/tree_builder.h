#pragma once

#include "tokenizer.h"
#include <vector>
#include <string_view>

namespace xmarkup {

struct ASTNode {
    enum Type { ROOT, ELEMENT, TEXT };
    Type                 type;
    std::string_view     tag_name;
    std::string_view     attributes;
    std::string_view     text;
    std::vector<ASTNode> children;
};

class TreeBuilder {
public:
    explicit TreeBuilder(uint16_t max_depth = 256, bool autocorrect = true);
    ASTNode build(const std::vector<Token>& tokens);

private:
    bool is_void_element(std::string_view tag) const;
    void handle_start_tag(const Token& tok);
    void handle_end_tag(const Token& tok);
    void handle_self_closing(const Token& tok);

    uint16_t max_depth_;
    bool autocorrect_;
    std::vector<ASTNode*> stack_;
    ASTNode root_;
};

} // namespace xmarkup
