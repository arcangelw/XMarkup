#pragma once

#include <cstdint>
#include <string>
#include <string_view>
#include <vector>

namespace xmarkup {

/**
 * @brief Token 类型枚举
 */
enum class TokenType {
    TEXT,              /**< 文本内容 */
    START_TAG,         /**< 开始标签（如 <div>） */
    END_TAG,           /**< 结束标签（如 </div>） */
    SELF_CLOSING_TAG,  /**< 自闭合标签（如 <br/>） */
};

/**
 * @brief 词法分析器状态枚举
 *
 * 实现 HTML5 规范中 HTML tokenizer 的子集状态机。
 * 参考：https://html.spec.whatwg.org/multipage/parsing.html
 */
enum class TokenizerState {
    DATA,               /**< 初始状态，收集文本直到遇到 '<' */
    TAG_OPEN,           /**< 遇到 '<'，判断标签类型 */
    TAG_NAME,           /**< 读取标签名 */
    END_TAG_OPEN,       /**< 遇到 '</'，期望标签名 */
    BEFORE_ATTR_NAME,   /**< 标签名结束，等待属性或 '>' */
    ATTR_NAME,          /**< 读取属性名 */
    AFTER_ATTR_NAME,    /**< 属性名后，等待 '=' 或下一个属性 */
    ATTR_VALUE_DOUBLE_Q,/**< 双引号属性值 */
    ATTR_VALUE_SINGLE_Q,/**< 单引号属性值 */
    ATTR_VALUE_UNQUOTED,/**< 无引号属性值 */
    SELF_CLOSING,       /**< 遇到 '/'，期望 '>' */
    COMMENT,            /**< 注释/声明处理 */
};

/**
 * @brief 词法单元
 *
 * 由 Tokenizer 从 HTML 字符串中提取的最小语法单位。
 * raw 和 attributes 为 string_view 指向原始输入；
 * tag_name 为 owned 字符串（小写化后的标签名）。
 */
struct Token {
    TokenType        type;       /**< token 类型 */
    std::string_view raw;        /**< 原始文本片段（含标签括号） */
    std::string      tag_name;   /**< 标签名（小写化，owned） */
    std::string_view attributes; /**< 属性字符串（标签名之后、'>' 之前的内容） */
};

/**
 * @brief HTML 词法分析器
 *
 * 将 HTML 字符串拆分为 Token 序列。支持：
 * - 文本节点提取
 * - 开始/结束/自闭合标签识别（标签名不区分大小写）
 * - 属性解析（双引号/单引号/无引号）
 * - HTML 注释和声明跳过
 * - script/style/noscript 原始文本跳过
 *
 * @code
 * Tokenizer tok("<b>Hello</b>");
 * while (tok.has_next()) {
 *     Token t = tok.next();
 *     // 处理 token...
 * }
 * @endcode
 */
class Tokenizer {
public:
    /**
     * @brief 构造词法分析器
     * @param html HTML 输入字符串视图（Tokenizer 不持有数据，调用者需保证生命周期）
     */
    explicit Tokenizer(std::string_view html);

    /** @brief 是否还有未读的 token */
    bool has_next() const;

    /** @brief 读取下一个 token */
    Token next();

private:
    /** @brief 是否到达输入末尾 */
    bool is_eof() const;
    /** @brief 判断是否为 ASCII 字母 */
    bool is_alpha(char c) const;
    /** @brief 判断是否为空白字符（空格、制表、换行、回车、换页） */
    bool is_whitespace(char c) const;

    /**
     * @brief 跳过原始文本内容（用于 script/style/noscript/textarea/title）
     * @param end_tag 闭合标签名（如 "script"），不区分大小写匹配
     */
    void skip_rawtext(const char* end_tag);

    /** @brief 根据 '=' 后的引号字符切换属性值解析状态 */
    void enter_attr_value();

    std::string_view html_;           /**< 输入 HTML 字符串视图 */
    size_t pos_ = 0;                  /**< 当前读取位置 */
    TokenizerState state_ = TokenizerState::DATA; /**< 当前状态机状态 */
    bool has_token_ = false;          /**< 是否有缓存的 token */
    Token pending_token_;             /**< 缓存的 token */
};

} // namespace xmarkup
