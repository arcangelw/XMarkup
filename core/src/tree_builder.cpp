#include "tree_builder.h"
#include "logger.h"

namespace xmarkup {

// HTML5 规范定义的 void 元素，不能有子节点
// https://html.spec.whatwg.org/multipage/syntax.html#void-elements
static const std::unordered_set<std::string_view>& void_element_set() {
    static const std::unordered_set<std::string_view> s = {
        "area", "base", "br", "col", "embed", "hr", "img", "input",
        "link", "meta", "param", "source", "track", "wbr"
    };
    return s;
}

// ============================================================
// 标签分类查表
// ============================================================

/// 自动关闭标签集：这些标签在特定条件下会被隐式关闭
static const std::unordered_set<std::string>& auto_closable_set() {
    static const std::unordered_set<std::string> s = {
        "p", "li", "dt", "dd", "tr", "td", "th", "thead", "tbody", "tfoot",
        "h1", "h2", "h3", "h4", "h5", "h6"
    };
    return s;
}

/// 扩展块级标签集（包含隐式关闭规则涉及的所有块级元素）
static const std::unordered_set<std::string>& extended_block_set() {
    static const std::unordered_set<std::string> s = {
        "p", "div", "blockquote", "pre", "h1", "h2", "h3", "h4", "h5", "h6",
        "ul", "ol", "li", "table", "tr", "td", "th", "thead", "tbody", "tfoot",
        "hr", "dl", "dt", "dd", "article", "section", "header", "footer",
        "main", "nav", "aside", "figure", "figcaption", "address"
    };
    return s;
}

/// 行内格式化标签集
static const std::unordered_set<std::string>& formatting_tag_set() {
    static const std::unordered_set<std::string> s = {
        "b", "strong", "i", "em", "u", "s", "strike", "del",
        "a", "code", "mark", "sub", "sup", "span"
    };
    return s;
}

/// 有格式语义的标签集（adoption agency 实际重建的标签）
static const std::unordered_set<std::string>& formatting_semantic_set() {
    static const std::unordered_set<std::string> s = {
        "b", "strong", "i", "em", "u", "s", "strike", "del",
        "a", "code", "mark"
    };
    return s;
}

/// 作用域边界标签集（阻止隐式关闭扫描跨越）
static const std::unordered_set<std::string>& scope_boundary_set() {
    static const std::unordered_set<std::string> s = {
        "div", "blockquote", "pre", "table", "ul", "ol",
        "video", "audio", "article", "section", "header",
        "footer", "main", "nav", "aside"
    };
    return s;
}

bool TreeBuilder::is_auto_closable(const std::string& tag) {
    return auto_closable_set().count(tag) > 0;
}

bool TreeBuilder::is_extended_block_level(const std::string& tag) {
    return extended_block_set().count(tag) > 0;
}

bool TreeBuilder::is_formatting_tag(const std::string& tag) {
    return formatting_tag_set().count(tag) > 0;
}

bool TreeBuilder::has_formatting_semantics(const std::string& tag) {
    return formatting_semantic_set().count(tag) > 0;
}

bool TreeBuilder::is_scope_boundary(const std::string& tag) {
    return scope_boundary_set().count(tag) > 0;
}

/// 隐式关闭规则表：parent 遇到 new_tag 时是否应该自动关闭
/// @see docs/superpowers/specs/2026-06-09-xmarkup-implicit-close-design.md §3
bool TreeBuilder::should_auto_close(const std::string& parent, const std::string& new_tag) {
    // 规则 1：<p> 遇任何块级元素（含自身）自动关闭
    if (parent == "p") return is_extended_block_level(new_tag);

    // 规则 2：<li> 遇 <li> 自动关闭
    if (parent == "li") return new_tag == "li";

    // 规则 3：<dt>/<dd> 互相关闭
    if (parent == "dt") return new_tag == "dt" || new_tag == "dd";
    if (parent == "dd") return new_tag == "dt" || new_tag == "dd";

    // 规则 4：<tr> 遇 <tr> 自动关闭
    if (parent == "tr") return new_tag == "tr";

    // 规则 5：<td>/<th> 遇 <td>/<th>/<tr> 自动关闭
    if (parent == "td") return new_tag == "td" || new_tag == "th" || new_tag == "tr";
    if (parent == "th") return new_tag == "td" || new_tag == "th" || new_tag == "tr";

    // 表格段互关
    if (parent == "thead") return new_tag == "tbody" || new_tag == "tfoot";
    if (parent == "tbody") return new_tag == "tbody" || new_tag == "tfoot";
    if (parent == "tfoot") return new_tag == "tbody";

    // 规则 6：<h1>-<h6> 遇块级元素自动关闭
    if (parent == "h1" || parent == "h2" || parent == "h3" ||
        parent == "h4" || parent == "h5" || parent == "h6") {
        return is_extended_block_level(new_tag);
    }

    return false;
}

// ============================================================
// 隐式关闭 & Adoption Agency
// ============================================================

/**
 * @brief 执行隐式关闭
 *
 * 从栈顶向下扫描，查找可以被 new_tag 触发隐式关闭的标签。
 * 扫描遇到 scope boundary 时停止，防止跨容器隐式关闭。
 *
 * @param new_tag 新遇到的开标签名
 */
void TreeBuilder::perform_implicit_close(const std::string& new_tag) {
    size_t pop_count = 0;
    for (auto it = stack_.rbegin(); it != stack_.rend() - 1; ++it) {
        const auto& parent_tag = (*it)->tag_name;

        if (should_auto_close(parent_tag, new_tag)) {
            Logger::warn("implicit close: <%s> closed by <%s>", parent_tag.c_str(), new_tag.c_str());
            stack_.resize(stack_.size() - pop_count - 1);
            return;
        }

        // 作用域边界：停止扫描，不跨容器隐式关闭
        if (is_scope_boundary(parent_tag)) {
            Logger::trace("implicit scan: scope boundary <%s> stops scan", parent_tag.c_str());
            break;
        }

        pop_count++;
    }
}

/**
 * @brief 执行 Adoption Agency Algorithm
 *
 * 当块级元素开始标签遇到栈中连续的行内格式化标签时：
 * 1. 收集栈顶连续的行内格式化标签
 * 2. 筛选有语义的标签（跳过 span/sub/sup）
 * 3. 弹出收集到的标签
 * 4. 将有语义的标签保存到 pending_adoption_，在入栈阶段重建
 *
 * @param new_tag 新遇到的开标签名
 */
void TreeBuilder::perform_adoption_agency(const std::string& new_tag) {
    // 只在块级元素触发
    if (!is_extended_block_level(new_tag)) return;

    // 从栈顶收集连续的行内格式化标签
    size_t all_collected = 0;   // 所有格式化标签数量（含无语义）
    std::vector<std::string> rebuild_list; // 有语义的重建列表

    size_t scan = stack_.size();
    while (scan > 1) {
        scan--;
        const auto& tag = stack_[scan]->tag_name;
        if (!is_formatting_tag(tag)) break;
        all_collected++;
        if (has_formatting_semantics(tag)) {
            rebuild_list.push_back(tag);
        }
    }

    if (rebuild_list.empty()) return;

    // 深度限制
    if (rebuild_list.size() > kMaxAdoptionDepth) {
        rebuild_list.resize(kMaxAdoptionDepth);
        Logger::warn("adoption depth truncated to %zu", kMaxAdoptionDepth);
    }

    // 日志
    std::string tags_str;
    for (size_t i = 0; i < rebuild_list.size(); i++) {
        if (i > 0) tags_str += ", ";
        tags_str += rebuild_list[i];
    }
    Logger::warn("adoption: [%s] rebuilt inside <%s>", tags_str.c_str(), new_tag.c_str());

    // 弹出所有收集到的标签（含无语义的）
    stack_.resize(stack_.size() - all_collected);

    // 保存重建列表，在入栈阶段使用
    pending_adoption_ = std::move(rebuild_list);
}

TreeBuilder::TreeBuilder(uint16_t max_depth, bool autocorrect)
    : max_depth_(max_depth), autocorrect_(autocorrect) {
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
    if (stack_.size() > 1) {
        std::string unclosed;
        for (size_t i = 1; i < stack_.size(); i++) {
            if (i > 1) unclosed += ", ";
            unclosed += "<" + stack_[i]->tag_name + ">";
        }
        Logger::warn("unclosed tags auto-closed: [%s]", unclosed.c_str());
    }
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

    // 隐式关闭检查（始终生效）
    perform_implicit_close(tok.tag_name);

    // Adoption agency（enable_autocorrect 时生效）— 任务 4 完善
    if (autocorrect_) {
        perform_adoption_agency(tok.tag_name);
    }

    // 深度限制检查（+1 因为栈底有 ROOT）
    if (stack_.size() >= static_cast<size_t>(max_depth_) + 1) {
        pending_adoption_.clear();  // 清空，防止泄漏到下一个元素
        return;
    }

    ASTNode elem;
    elem.type = ASTNode::ELEMENT;
    elem.tag_name = tok.tag_name;
    elem.attributes = tok.attributes;
    stack_.back()->children.push_back(std::move(elem));

    // 新节点入栈（指向刚插入的最后一个子节点）
    stack_.push_back(&stack_.back()->children.back());

    // Adoption 重建行内格式化链：从外到内依次重建
    if (!pending_adoption_.empty()) {
        for (auto it = pending_adoption_.rbegin(); it != pending_adoption_.rend(); ++it) {
            ASTNode fmt_clone;
            fmt_clone.type = ASTNode::ELEMENT;
            fmt_clone.tag_name = *it;
            Logger::trace("adoption rebuild: pushing <%s> clone", it->c_str());
            stack_.back()->children.push_back(std::move(fmt_clone));
            stack_.push_back(&stack_.back()->children.back());
        }
        pending_adoption_.clear();
    }
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
    Logger::warn("extra close tag ignored: </%s>", tok.tag_name.c_str());
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
    return void_element_set().count(tag) > 0;
}

} // namespace xmarkup
