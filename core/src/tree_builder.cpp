#include "tree_builder.h"

namespace xmarkup {

// HTML5 规范定义的 void 元素，不能有子节点
// https://html.spec.whatwg.org/multipage/syntax.html#void-elements
static const std::string_view kVoidElements[] = {
    "area", "base", "br", "col", "embed", "hr", "img", "input",
    "link", "meta", "param", "source", "track", "wbr"
};

TreeBuilder::TreeBuilder(uint16_t max_depth, bool autocorrect)
    : max_depth_(max_depth), autocorrect_(autocorrect) {
    (void)autocorrect_; // TODO: 自动纠错逻辑在后续增强中使用
}

/**
 * @brief 从 Token 序列构建 AST
 *
 * 使用栈管理标签嵌套关系：
 * - 栈底始终是 ROOT 节点
 * - 遇到 START_TAG：创建节点并入栈（void 元素除外）
 * - 遇到 END_TAG：在栈中从顶向下查找匹配的开始标签，弹出到该层
 * - 遇到 SELF_CLOSING_TAG：创建叶子节点，不入栈
 * - 未闭合标签自动补齐（栈中剩余节点留在 root 下）
 */
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

/**
 * @brief 处理开始标签
 *
 * 策略：
 * 1. void 元素（如 <br>, <img>）：不入栈，直接作为叶子节点挂到当前栈顶
 * 2. 超过最大嵌套深度：忽略该标签（防止恶意输入）
 * 3. 普通标签：创建节点挂到当前栈顶，然后入栈成为新的当前父节点
 */
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

    // 深度限制检查（+1 因为栈底有 ROOT）
    if (stack_.size() >= static_cast<size_t>(max_depth_) + 1) {
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

/**
 * @brief 处理结束标签
 *
 * 策略：从栈顶向下查找匹配的开始标签。
 * - 找到匹配：弹出到匹配层（含），中间未闭合的标签自动补齐
 * - 未找到匹配：多余的闭合标签忽略（HTML 容错）
 */
void TreeBuilder::handle_end_tag(const Token& tok) {
    if (stack_.size() <= 1) {
        // 栈只剩 ROOT，多余的闭合标签忽略
        return;
    }

    // 从栈顶向下查找匹配的开始标签
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

/**
 * @brief 处理自闭合标签
 *
 * 自闭合标签（如 <br/>）作为叶子节点，不入栈。
 */
void TreeBuilder::handle_self_closing(const Token& tok) {
    ASTNode elem;
    elem.type = ASTNode::ELEMENT;
    elem.tag_name = tok.tag_name;
    elem.attributes = tok.attributes;
    stack_.back()->children.push_back(std::move(elem));
}

bool TreeBuilder::is_void_element(std::string_view tag) const {
    for (const auto& vt : kVoidElements) {
        if (tag == vt) return true;
    }
    return false;
}

} // namespace xmarkup
