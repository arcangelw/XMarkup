#pragma once

#include <cstdint>
#include <string_view>
#include <vector>

namespace xmarkup {

/**
 * @brief UTF-8 byte offset 到 UTF-16 编码单元索引的映射条目
 */
struct ByteToUTF16 {
    uint32_t byte_offset; /**< UTF-8 byte offset */
    uint32_t utf16_offset; /**< 对应的 UTF-16 编码单元索引 */
};

/**
 * @brief UTF-16 索引映射器
 *
 * 建立从 UTF-8 byte offset 到 UTF-16 编码单元索引的映射表，
 * 用于将内部 span（byte offset）转换为平台 API 需要的 UTF-16 索引。
 *
 * UTF-8 → UTF-16 长度映射：
 * - 1 字节 (U+0000-U+007F): UTF-16 1 单元
 * - 2 字节 (U+0080-U+07FF): UTF-16 1 单元
 * - 3 字节 (U+0800-U+FFFF): UTF-16 1 单元
 * - 4 字节 (U+10000-U+10FFFF): UTF-16 2 单元（surrogate pair）
 *
 * @code
 * UTF16Indexer indexer;
 * indexer.build("Hello 世界");  // UTF-8 输入
 * uint32_t idx = indexer.byte_to_utf16(6);  // "世" 的 UTF-16 索引
 * @endcode
 */
class UTF16Indexer {
public:
    /**
     * @brief 构建 UTF-8 → UTF-16 映射表
     * @param utf8_text UTF-8 编码的文本
     */
    void build(std::string_view utf8_text);

    /**
     * @brief 将 UTF-8 byte offset 转换为 UTF-16 编码单元索引
     * @param byte_offset UTF-8 byte offset
     * @return 对应的 UTF-16 编码单元索引
     * @note 如果 byte_offset 不在映射表中（如指向多字节序列中间），
     *       返回前一个已知位置的 UTF-16 索引。
     */
    uint32_t byte_to_utf16(uint32_t byte_offset) const;

private:
    std::vector<ByteToUTF16> mapping_; /**< byte offset → UTF-16 index 映射表，按 byte_offset 升序 */
};

} // namespace xmarkup
