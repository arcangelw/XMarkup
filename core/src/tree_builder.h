#pragma once

#include "tokenizer.h"
#include <vector>
#include <string_view>

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
    std::string_view     tag_name;    /**< 标签名（仅 ELEMENT 类型有效） */
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
 * - 错嵌套标签纠错（可选）
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
     * @param autocorrect  是否启用自动纠错（处理错嵌套标签）
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

    /** @brief 处理开始标签 token */
    void handle_start_tag(const Token& tok);
    /** @brief 处理结束标签 token */
    void handle_end_tag(const Token& tok);
    /** @brief 处理自闭合标签 token */
    void handle_self_closing(const Token& tok);
    /** @brief 纠正错嵌套标签 */
    void autocorrect_misnested(std::string_view tag);

    uint16_t max_depth_;         /**< 最大嵌套深度限制 */
    bool autocorrect_;           /**< 是否启用自动纠错 */
    std::vector<ASTNode*> stack_; /**< 节点栈，管理当前嵌套路径 */
    ASTNode root_;               /**< 根节点（build 调用间复用） */
};

} // namespace xmarkup
