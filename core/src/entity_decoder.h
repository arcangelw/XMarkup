#pragma once

#include <string>
#include <string_view>

namespace xmarkup {

/**
 * @brief HTML 实体解码器
 *
 * 将 HTML 实体引用（如 &amp;, &#60;, &#x3c;）解码为对应的 UTF-8 字符。
 * 支持三种格式：
 * - 命名实体：&amp; &lt; &gt; &quot; 等（约 120 个常用实体）
 * - 十进制数字实体：&#60; &#20013;
 * - 十六进制数字实体：&#x3c; &#x4e2d;
 *
 * 容错策略：
 * - 缺少分号的命名实体会尝试最长匹配（如 &amp hello → & hello）
 * - 超出 Unicode 范围的数字实体保留原始文本
 * - Surrogate 范围和零值码点视为无效，保留原始文本
 * - 未知命名实体保留原始文本
 *
 * @code
 * std::string result = EntityDecoder::decode("1 &lt; 2 &amp; 3");
 * // result == "1 < 2 & 3"
 * @endcode
 */
class EntityDecoder {
public:
    /**
     * @brief 解码字符串中的所有 HTML 实体
     * @param text 包含 HTML 实体的输入字符串
     * @return 解码后的 UTF-8 字符串
     */
    static std::string decode(std::string_view text);

private:
    /**
     * @brief 尝试从指定位置解码一个 HTML 实体
     * @param text       输入文本
     * @param pos        '&' 的位置
     * @param entity_end [out] 实体结束位置（不含）
     * @param decoded    [out] 解码结果
     * @return true 表示成功解码
     */
    static bool try_decode_entity(std::string_view text, size_t pos,
                                  size_t& entity_end, std::string& decoded);

    /**
     * @brief 尝试匹配命名实体
     * @param name    实体名称（不含 & 和 ;）
     * @param decoded [out] 解码结果
     * @return true 表示匹配成功
     */
    static bool try_named_entity(std::string_view name, std::string& decoded);

    /**
     * @brief 尝试解码数字实体
     * @param value   数字部分（不含 &# 和 ;）
     * @param is_hex  是否为十六进制格式
     * @param decoded [out] 解码结果
     * @return true 表示解码成功（有效码点）
     */
    static bool try_numeric_entity(std::string_view value, bool is_hex,
                                   std::string& decoded);
};

} // namespace xmarkup
