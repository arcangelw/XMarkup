#include <gtest/gtest.h>
#include "entity_decoder.h"

using namespace xmarkup;

TEST(EntityDecoder, NamedEntities) {
    EXPECT_EQ(EntityDecoder::decode("&amp;"), "&");
    EXPECT_EQ(EntityDecoder::decode("&lt;"), "<");
    EXPECT_EQ(EntityDecoder::decode("&gt;"), ">");
    EXPECT_EQ(EntityDecoder::decode("&quot;"), "\"");
    EXPECT_EQ(EntityDecoder::decode("&apos;"), "'");
    EXPECT_EQ(EntityDecoder::decode("&nbsp;"), "\xC2\xA0");
}

TEST(EntityDecoder, NumericDecimal) {
    EXPECT_EQ(EntityDecoder::decode("&#60;"), "<");
    EXPECT_EQ(EntityDecoder::decode("&#20013;"), "\xe4\xb8\xad"); // "中"
}

TEST(EntityDecoder, NumericHex) {
    EXPECT_EQ(EntityDecoder::decode("&#x3c;"), "<");
    EXPECT_EQ(EntityDecoder::decode("&#x4e2d;"), "\xe4\xb8\xad"); // "中"
}

TEST(EntityDecoder, MixedText) {
    EXPECT_EQ(EntityDecoder::decode("1 &lt; 2 &amp; 3 &gt; 0"), "1 < 2 & 3 > 0");
}

TEST(EntityDecoder, IncompleteEntity) {
    EXPECT_EQ(EntityDecoder::decode("&amp hello"), "& hello");
    EXPECT_EQ(EntityDecoder::decode("&unknown;"), "&unknown;");
}

TEST(EntityDecoder, NoEntities) {
    EXPECT_EQ(EntityDecoder::decode("plain text"), "plain text");
}

TEST(EntityDecoder, EmptyInput) {
    EXPECT_EQ(EntityDecoder::decode(""), "");
}
