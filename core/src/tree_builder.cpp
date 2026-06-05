#include "tree_builder.h"

namespace xmarkup {

TreeBuilder::TreeBuilder(uint16_t max_depth, bool autocorrect)
    : max_depth_(max_depth), autocorrect_(autocorrect) {
    (void)autocorrect_; // TODO: 自动纠错逻辑在后续增强中使用
}

ASTNode TreeBuilder::build(const std::vector<Token>& tokens) {
    ASTNode root;
    root.type = ASTNode::ROOT;
    stack_.clear();
    stack_.push_back(&root);

    for (const auto& tok : tokens) {
        switch (tok.type) {
        case TokenType::TEXT:
            if (!tok.raw.empty()) {
                ASTNode text_node;
                text_node.type = ASTNode::TEXT;
                text_node.text = tok.raw;
                stack_.back()->children.push_back(std::move(text_node));
            }
            break;

        case TokenType::START_TAG:
            handle_start_tag(tok);
            break;

        case TokenType::END_TAG:
            handle_end_tag(tok);
            break;

        case TokenType::SELF_CLOSING_TAG:
            handle_self_closing(tok);
            break;
        }
    }

    // 未闭合的标签自动补齐（栈中剩余的节点会留在栈中，root 已包含它们）
    stack_.clear();
    return root;
}

void TreeBuilder::handle_start_tag(const Token& tok) {
    // void 元素不入栈，直接作为叶子节点
    if (is_void_element(tok.tag_name)) {
        ASTNode elem;
        elem.type = ASTNode::ELEMENT;
        elem.tag_name = tok.tag_name;
        elem.attributes = tok.attributes;
        stack_.back()->children.push_back(std::move(elem));
        return;
    }

    // 深度限制检查
    if (stack_.size() >= static_cast<size_t>(max_depth_) + 1) {
        // 超过最大嵌套深度，当作文本忽略（或跳过）
        return;
    }

    ASTNode elem;
    elem.type = ASTNode::ELEMENT;
    elem.tag_name = tok.tag_name;
    elem.attributes = tok.attributes;
    stack_.back()->children.push_back(std::move(elem));

    // 新节点入栈（指向刚插入的最后一个子节点）
    stack_.push_back(&stack_.back()->children.back());
}

void TreeBuilder::handle_end_tag(const Token& tok) {
    if (stack_.size() <= 1) {
        // 栈只剩 root，多余的闭合标签忽略
        return;
    }

    // 在栈中从顶向下查找匹配的开始标签
    size_t pop_count = 0;
    for (auto it = stack_.rbegin(); it != stack_.rend() - 1; ++it) {
        pop_count++;
        if ((*it)->tag_name == tok.tag_name) {
            // 弹出到匹配层（含匹配层本身）
            stack_.resize(stack_.size() - pop_count);
            return;
        }
    }

    // 未找到匹配，多余的闭合标签忽略
}

void TreeBuilder::handle_self_closing(const Token& tok) {
    // 自闭合标签作为叶子节点，不入栈
    ASTNode elem;
    elem.type = ASTNode::ELEMENT;
    elem.tag_name = tok.tag_name;
    elem.attributes = tok.attributes;
    stack_.back()->children.push_back(std::move(elem));
}

void TreeBuilder::autocorrect_misnested(std::string_view tag) {
    // 在栈中查找标签
    for (auto it = stack_.rbegin(); it != stack_.rend() - 1; ++it) {
        if ((*it)->tag_name == tag) {
            auto depth = stack_.rend() - it;
            stack_.resize(static_cast<size_t>(depth));
            return;
        }
    }
}

bool TreeBuilder::is_void_element(std::string_view tag) const {
    // HTML void 元素列表
    static const std::string_view void_tags[] = {
        "area", "base", "br", "col", "embed", "hr", "img", "input",
        "link", "meta", "param", "source", "track", "wbr"
    };
    for (const auto& vt : void_tags) {
        if (tag == vt) return true;
    }
    return false;
}

} // namespace xmarkup
