#pragma once

#include <cstdint>
#include <string_view>
#include <vector>

namespace xmarkup {

struct ByteToUTF16 {
    uint32_t byte_offset;
    uint32_t utf16_offset;
};

class UTF16Indexer {
public:
    void build(std::string_view utf8_text);
    uint32_t byte_to_utf16(uint32_t byte_offset) const;

private:
    std::vector<ByteToUTF16> mapping_;
};

} // namespace xmarkup
