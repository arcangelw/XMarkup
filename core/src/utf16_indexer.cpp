#include "utf16_indexer.h"
#include <algorithm>

namespace xmarkup {

/**
 * @brief 构建 UTF-8 → UTF-16 映射表
 *
 * 遍历 UTF-8 文本的每个字符，根据前导字节判定序列长度：
 * - 0x00-0x7F (0xxxxxxx):           1 字节 → UTF-16 1 单元
 * - 0x80-0xBF (continuation):       不应作为前导字节（非法 UTF-8 不处理）
 * - 0xC0-0xDF (110xxxxx):           2 字节 → UTF-16 1 单元
 * - 0xE0-0xEF (1110xxxx):           3 字节 → UTF-16 1 单元
 * - 0xF0-0xF7 (11110xxx):           4 字节 → UTF-16 2 单元（surrogate pair）
 *
 * 映射表按 byte_offset 升序存储，每个条目记录一个字符边界。
 */
void UTF16Indexer::build(std::string_view utf8_text) {
    mapping_.clear();
    if (utf8_text.empty()) return;

    uint32_t byte_off = 0;
    uint32_t utf16_off = 0;
    mapping_.push_back({0, 0}); // 起始位置映射

    while (byte_off < utf8_text.size()) {
        uint8_t c = static_cast<uint8_t>(utf8_text[byte_off]);
        uint32_t seq_len = 1;
        uint32_t utf16_inc = 1;

        // 根据 UTF-8 前导字节的高位模式判定序列长度
        if (c < 0x80) {
            // ASCII: 0xxxxxxx → 1 字节, 1 UTF-16 单元
            seq_len = 1; utf16_inc = 1;
        } else if ((c & 0xE0) == 0xC0) {
            // 2 字节序列: 110xxxxx → U+0080-U+07FF, 1 UTF-16 单元
            seq_len = 2; utf16_inc = 1;
            // 验证续字节
            if (byte_off + 1 >= utf8_text.size() ||
                (static_cast<uint8_t>(utf8_text[byte_off + 1]) & 0xC0) != 0x80) {
                seq_len = 1; // 非法/缺失续字节，降级为单字节
            }
        } else if ((c & 0xF0) == 0xE0) {
            // 3 字节序列: 1110xxxx → U+0800-U+FFFF, 1 UTF-16 单元
            seq_len = 3; utf16_inc = 1;
            if (byte_off + 2 >= utf8_text.size() ||
                (static_cast<uint8_t>(utf8_text[byte_off + 1]) & 0xC0) != 0x80 ||
                (static_cast<uint8_t>(utf8_text[byte_off + 2]) & 0xC0) != 0x80) {
                seq_len = 1;
            }
        } else if ((c & 0xF8) == 0xF0) {
            // 4 字节序列: 11110xxx → U+10000-U+10FFFF, 2 UTF-16 单元（surrogate pair）
            seq_len = 4; utf16_inc = 2;
            if (byte_off + 3 >= utf8_text.size() ||
                (static_cast<uint8_t>(utf8_text[byte_off + 1]) & 0xC0) != 0x80 ||
                (static_cast<uint8_t>(utf8_text[byte_off + 2]) & 0xC0) != 0x80 ||
                (static_cast<uint8_t>(utf8_text[byte_off + 3]) & 0xC0) != 0x80) {
                seq_len = 1;
            }
        }

        byte_off += seq_len;
        utf16_off += utf16_inc;
        mapping_.push_back({byte_off, utf16_off});
    }
}

/**
 * @brief 将 UTF-8 byte offset 转换为 UTF-16 编码单元索引
 *
 * 使用二分查找在映射表中定位。如果 byte_offset 恰好是字符边界，
 * 返回对应的 UTF-16 索引；如果指向多字节序列中间，返回前一个
 * 字符边界的 UTF-16 索引。
 */
uint32_t UTF16Indexer::byte_to_utf16(uint32_t byte_offset) const {
    if (mapping_.empty()) return 0;
    auto it = std::lower_bound(mapping_.begin(), mapping_.end(), byte_offset,
        [](const ByteToUTF16& a, uint32_t b) { return a.byte_offset < b; });
    if (it != mapping_.end() && it->byte_offset == byte_offset) return it->utf16_offset;
    if (it != mapping_.begin()) { --it; return it->utf16_offset; }
    return 0;
}

} // namespace xmarkup
