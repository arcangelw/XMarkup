#pragma once

#include "tokenizer.h"
#include <vector>
#include <string_view>
#include <unordered_set>
#include <unordered_map>

namespace xmarkup {

/**
 * @brief AST 节点
 *
 * 解析产出的树形结构，支持三种节点类型：
 * - ROOT: 虚拟根节点，包含所有顶层子节点
 * - ELEMENT: HTML 元素，可能包含子节点和属性
 * - TEXT: 文本节点，叶子节点
 */
struct ASTNode {
    enum Type { ROOT, ELEMENT, TEXT }; /**< 节点类型 */
    Type                 type;        /**< 当前节点类型 */
    std::string          tag_name;    /**< 标签名（小写化，仅 ELEMENT 类型有效） */
    std::string_view     attributes;  /**< 属性字符串（仅 ELEMENT 类型有效） */
    std::string_view     text;        /**< 文本内容（仅 TEXT 类型有效） */
    std::vector<ASTNode> children;    /**< 子节点列表（ROOT 和 ELEMENT 可有子节点） */
};

/**
 * @brief AST 构建器——将 Token 序列构建为树形结构
 *
 * 处理：
 * - 标签嵌套（使用栈管理父子关系）
 * - void 元素识别（不入栈，直接作为叶子节点）
 * - 嵌套深度限制（防止恶意输入导致栈溢出）
 * - 未闭合标签自动补齐（栈中剩余节点保留在根节点下）
 * - HTML5 隐式关闭 6 条规则（始终生效）
 * - Adoption Agency Algorithm（enable_autocorrect 控制）
 * - Scope Boundary 防跨容器关闭
 *
 * @code
 * TreeBuilder builder(256, true);
 * ASTNode ast = builder.build(tokens);
 * // ast.type == ASTNode::ROOT
 * // ast.children 包含所有顶层节点
 * @endcode
 */
class TreeBuilder {
public:
    /**
     * @brief 构建树构建器
     * @param max_depth    最大嵌套深度，超过后忽略后续标签（防恶意输入）
     * @param autocorrect  是否启用 Adoption Agency Algorithm（行内标签跨块级重建）
     */
    explicit TreeBuilder(uint16_t max_depth = 256, bool autocorrect = true);

    /**
     * @brief 从 Token 序列构建 AST
     * @param tokens Tokenizer 产出的 token 列表
     * @return AST 根节点（type 为 ROOT）
     */
    ASTNode build(const std::vector<Token>& tokens);

private:
    /**
     * @brief 判断标签是否为 HTML void 元素
     * @param tag 标签名
     * @return true 表示该标签不能有子节点
     */
    bool is_void_element(std::string_view tag) const;

    // === 隐式关闭 & Adoption Agency ===
    static bool is_auto_closable(const std::string& tag);
    static bool should_auto_close(const std::string& parent_tag, const std::string& new_tag);
    static bool is_extended_block_level(const std::string& tag);
    static bool is_formatting_tag(const std::string& tag);
    static bool has_formatting_semantics(const std::string& tag);
    static bool is_scope_boundary(const std::string& tag);

    void perform_implicit_close(const std::string& new_tag);
    void perform_adoption_agency(const std::string& new_tag);

    /** @brief 处理开始标签 token */
    void handle_start_tag(const Token& tok);
    /** @brief 处理结束标签 token */
    void handle_end_tag(const Token& tok);
    /** @brief 处理自闭合标签 token */
    void handle_self_closing(const Token& tok);

    uint16_t max_depth_;         /**< 最大嵌套深度限制 */
    bool autocorrect_;           /**< 是否启用自动纠错 */
    static constexpr size_t kMaxAdoptionDepth = 32; /**< Adoption agency 重建深度上限 */
    std::vector<std::string> pending_adoption_; /**< Adoption 等待重建的标签列表 */
    /**
     * 节点栈，管理当前嵌套路径。
     *
     * 指针安全性不变式：
     * stack_ 存储指向 parent->children 中元素的裸指针。隐式关闭通过
     * stack_.resize() 弹出栈元素实现，不修改 AST 树结构（children vector），
     * 因此不会触发 parent children 的 realloc，指针始终有效。
     *
     * Adoption Agency 同样只操作栈（resize + 新节点入栈），不修改已有节点
     * 的 children，维持不变式。
     */
    std::vector<ASTNode*> stack_;
};

} // namespace xmarkup
