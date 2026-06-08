#pragma once

#include "tree_builder.h"
#include "xmarkup/xmarkup.h"
#include <vector>
#include <string>
#include <string_view>

namespace xmarkup {

/**
 * @brief 内部样式区间（byte offset 粒度）
 *
 * StyleResolver 产出的中间结果，使用 UTF-8 byte offset 定位。
 * 后续由 ParserInternal 通过 UTF16Indexer 转换为 UTF-16 索引的 XMSpan。
 */
struct InternalSpan {
    uint32_t    byte_start = 0; /**< 区间起始（含），UTF-8 byte offset */
    uint32_t    byte_end = 0;   /**< 区间结束（不含），UTF-8 byte offset */
    int         tag = 0;        /**< XMTagType 值，0 表示无标签 */
    int         style = 0;      /**< XMStyleType 值，0 表示无样式 */
    std::string value;          /**< 属性/样式值（如 href、颜色值） */
};

/**
 * @brief 扁平化解析结果
 *
 * StyleResolver 对 AST 做 DFS 遍历后产出的纯文本 + 样式区间列表。
 */
struct FlattenResult {
    std::string               text;  /**< 解析后的纯文本（UTF-8） */
    std::vector<InternalSpan> spans; /**< 样式区间列表（outside-in 顺序） */
};

/**
 * @brief 样式解析器——将 AST 转换为扁平文本 + 样式区间
 *
 * 对 AST 做 DFS 遍历，产出：
 * - 纯文本（HTML 实体已解码，空白已折叠/保留）
 * - 标签 span（HTML 标签 → XMTagType）
 * - 样式 span（CSS inline style → XMStyleType）
 * - 占位字符（void 元素插入 U+FFFC/\n，保证 span range 非零）
 *
 * Span 顺序保证：outside-in（外层 span 在前，内层在后），
 * 同一层级按出现顺序排列。
 */
class StyleResolver {
public:
    /**
     * @brief 构造样式解析器
     * @param base_font_size 基准字号（px），用于 em/rem/% 单位换算
     */
    explicit StyleResolver(float base_font_size = 16.0f);

    /**
     * @brief 解析 AST，产出扁平化结果
     * @param root AST 根节点（由 TreeBuilder 产出）
     * @return 扁平化结果，包含纯文本和样式区间
     */
    FlattenResult resolve(const ASTNode& root);

private:
    /**
     * @brief DFS 遍历 AST 节点
     * @param node   当前节点
     * @param inside_pre 是否在 <pre> 标签内（影响空白处理策略）
     */
    void dfs(const ASTNode& node, bool inside_pre);

    /**
     * @brief 确保已输出文本末尾有换行符
     *
     * 如果已输出文本非空且最后一个字符不是 '\\n'，追加一个换行符。
     * 用于块级元素进入前和退出后，保证块级元素之间的换行分隔，
     * 同时避免连续块级元素之间产生多余空行。
     */
    void ensure_newline();

    /** @brief 将 HTML 标签名映射为 XMTagType 值 */
    int  map_tag(std::string_view tag_name) const;

    /** @brief 解析内联 style 属性（已弃用，由 add_style_spans 替代） */
    void parse_inline_style(std::string_view style_str);

    /**
     * @brief 解析 CSS inline style 字符串，添加样式 span
     * @param style_str CSS 属性字符串（如 "color:red; font-size:16px"）
     * @param start     span 的 byte 起始位置
     * @param end       span 的 byte 结束位置
     */
    void add_style_spans(const std::string& style_str, uint32_t start, uint32_t end);

    /**
     * @brief 从 HTML 属性字符串中提取指定属性值
     * @param attrs     属性字符串（如 'href="..." src="..."')
     * @param attr_name 要提取的属性名
     * @param out_value 输出属性值
     */
    void extract_attribute_value(std::string_view attrs, const char* attr_name,
                                 std::string& out_value) const;

    /**
     * @brief 将颜色值标准化为 #RRGGBB 格式
     * @param value 输入值（支持 #RGB, #RRGGBB, rgb(r,g,b), 颜色名）
     * @return 标准化后的颜色字符串，无法识别时原样返回
     */
    std::string normalize_color(std::string_view value) const;

    /**
     * @brief 将字号值标准化为 px 数字字符串
     * @param value 输入值（支持 16px, 1.5em, 12pt, 150%, 16（无单位））
     * @return px 数字字符串（如 "16", "21.75"），最多 2 位小数
     */
    std::string normalize_font_size(std::string_view value) const;

    /**
     * @brief 将 font-weight 值标准化
     * @param value 输入值（normal/bold/100-900）
     * @return 原样返回（当前不做转换）
     */
    std::string normalize_font_weight(std::string_view value) const;

    float base_font_size_;                    /**< 基准字号（px），用于单位换算 */
    FlattenResult result_;                     /**< 累积的解析结果 */
    std::vector<std::string_view> parent_stack_; /**< 父标签栈，用于 <source> 上下文判定 */
    uint32_t byte_offset_ = 0;                /**< 当前文本写入位置（UTF-8 byte offset） */
};

} // namespace xmarkup
