#include "utf16_indexer.h"
#include <algorithm>

namespace xmarkup {

void UTF16Indexer::build(std::string_view utf8_text) {
    mapping_.clear();
    if (utf8_text.empty()) return;

    uint32_t byte_off = 0;
    uint32_t utf16_off = 0;
    mapping_.push_back({0, 0});

    while (byte_off < utf8_text.size()) {
        uint8_t c = static_cast<uint8_t>(utf8_text[byte_off]);
        uint32_t seq_len = 1;
        uint32_t utf16_inc = 1;

        if (c < 0x80) {
            seq_len = 1; utf16_inc = 1;
        } else if ((c & 0xE0) == 0xC0) {
            seq_len = 2; utf16_inc = 1;
        } else if ((c & 0xF0) == 0xE0) {
            seq_len = 3; utf16_inc = 1;
        } else if ((c & 0xF8) == 0xF0) {
            seq_len = 4; utf16_inc = 2;
        }

        byte_off += seq_len;
        utf16_off += utf16_inc;
        mapping_.push_back({byte_off, utf16_off});
    }
}

uint32_t UTF16Indexer::byte_to_utf16(uint32_t byte_offset) const {
    if (mapping_.empty()) return 0;
    auto it = std::lower_bound(mapping_.begin(), mapping_.end(), byte_offset,
        [](const ByteToUTF16& a, uint32_t b) { return a.byte_offset < b; });
    if (it != mapping_.end() && it->byte_offset == byte_offset) return it->utf16_offset;
    if (it != mapping_.begin()) { --it; return it->utf16_offset; }
    return 0;
}

} // namespace xmarkup
