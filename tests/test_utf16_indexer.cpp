#include <gtest/gtest.h>
#include "utf16_indexer.h"

using namespace xmarkup;

TEST(UTF16Indexer, PureASCII) {
    UTF16Indexer idx;
    idx.build("Hello");
    EXPECT_EQ(idx.byte_to_utf16(0), 0u);
    EXPECT_EQ(idx.byte_to_utf16(3), 3u);
    EXPECT_EQ(idx.byte_to_utf16(5), 5u);
}

TEST(UTF16Indexer, ChineseCharacters) {
    // "你好" = 6 UTF-8 bytes, 2 UTF-16 code units
    UTF16Indexer idx;
    idx.build("\xe4\xbd\xa0\xe5\xa5\xbd"); // "你好"
    EXPECT_EQ(idx.byte_to_utf16(0), 0u);
    EXPECT_EQ(idx.byte_to_utf16(3), 1u);  // "好" starts at UTF-16 index 1
    EXPECT_EQ(idx.byte_to_utf16(6), 2u);  // end
}

TEST(UTF16Indexer, Emoji) {
    // "😊" = 4 UTF-8 bytes, 2 UTF-16 code units (surrogate pair)
    UTF16Indexer idx;
    idx.build("\xf0\x9f\x98\x8a"); // "😊"
    EXPECT_EQ(idx.byte_to_utf16(0), 0u);
    EXPECT_EQ(idx.byte_to_utf16(4), 2u);  // surrogate pair = 2 UTF-16 units
}

TEST(UTF16Indexer, MixedContent) {
    // "Hi你好😊" = 2+6+4 = 12 bytes, 2+2+2 = 6 UTF-16 units
    UTF16Indexer idx;
    idx.build("Hi\xe4\xbd\xa0\xe5\xa5\xbd\xf0\x9f\x98\x8a");
    EXPECT_EQ(idx.byte_to_utf16(0), 0u);   // H
    EXPECT_EQ(idx.byte_to_utf16(2), 2u);   // 你 start
    EXPECT_EQ(idx.byte_to_utf16(8), 4u);   // 😊 start
    EXPECT_EQ(idx.byte_to_utf16(12), 6u);  // end
}

TEST(UTF16Indexer, EmptyString) {
    UTF16Indexer idx;
    idx.build("");
    EXPECT_EQ(idx.byte_to_utf16(0), 0u);
}

// ============================================================
// Code Review 修复：非法 UTF-8 续字节降级处理
// ============================================================

TEST(UTF16Indexer, InvalidContinuationByte) {
    UTF16Indexer idx;
    // 孤立 continuation byte 0x80（= 128）
    std::string invalid = "A\x80" "B";
    idx.build(invalid);
    // 0x80 被视为 1 字节 → 1 UTF-16 单元
    // byte 2 = 'B' → byte_offset=2, utf16_index=2
    EXPECT_EQ(idx.byte_to_utf16(2), 2u);
}

TEST(UTF16Indexer, ByteOffsetInMiddleOfChar) {
    // byte_to_utf16(1) 在 3 字节序列中间 → 前回退到位置 0
    UTF16Indexer idx;
    idx.build("\xe4\xbd\xa0"); // "你"
    EXPECT_EQ(idx.byte_to_utf16(1), 0u); // 3 字节序列中间，回退
    EXPECT_EQ(idx.byte_to_utf16(2), 0u); // 3 字节序列中间，回退
    EXPECT_EQ(idx.byte_to_utf16(3), 1u); // 序列结束，正确前进
}

TEST(UTF16Indexer, Multiple4ByteSequences) {
    // 两个 4 字节 emoji → 共 4 个 UTF-16 单元
    UTF16Indexer idx;
    idx.build("\xf0\x9f\x98\x8a\xf0\x9f\x8e\x89"); // 😊🎉
    EXPECT_EQ(idx.byte_to_utf16(0), 0u);
    EXPECT_EQ(idx.byte_to_utf16(4), 2u);  // 第一个 surrogate pair
    EXPECT_EQ(idx.byte_to_utf16(8), 4u);  // end
}

TEST(UTF16Indexer, TruncatedMultiByte) {
    UTF16Indexer idx;
    // 2 字节序列只有前导字节（0xC3 是 2 字节序列的前导）
    std::string truncated = "\xC3";
    idx.build(truncated);
    // 0xC3 被视为 1 字节（缺失续字节）
    EXPECT_EQ(idx.byte_to_utf16(1), 1u);
}
