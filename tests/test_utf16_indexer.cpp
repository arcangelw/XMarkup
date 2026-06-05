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
