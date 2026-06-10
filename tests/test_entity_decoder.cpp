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

TEST(EntityDecoder, OversizedNumericEntity) {
    // 超大数字实体应返回原始文本（超出 Unicode 范围）
    EXPECT_EQ(EntityDecoder::decode("&#999999999;"), "&#999999999;");
}

TEST(EntityDecoder, ZeroNumericEntity) {
    // 零值实体应返回原始文本（无效码点）
    EXPECT_EQ(EntityDecoder::decode("&#0;"), "&#0;");
}

TEST(EntityDecoder, SurrogateRangeEntity) {
    // surrogate 范围码点应返回原始文本
    EXPECT_EQ(EntityDecoder::decode("&#xD800;"), "&#xD800;");
}

TEST(EntityDecoder, ConsecutiveEntities) {
    // &amp; → &, &lt; → <, &gt; → >
    EXPECT_EQ(EntityDecoder::decode("&amp;&lt;&gt;"), "&<>");
    EXPECT_EQ(EntityDecoder::decode("&amp;&amp;"), "&&");
    // 连续实体解码："<b>"
    EXPECT_EQ(EntityDecoder::decode("&lt;b&gt;"), "<b>");
}

TEST(EntityDecoder, TrailingAmpersand) {
    // & 后在末尾没有更多字符
    EXPECT_EQ(EntityDecoder::decode("text&amp"), "text&");
    EXPECT_EQ(EntityDecoder::decode("text&"), "text&");
    EXPECT_EQ(EntityDecoder::decode("&"), "&");
}

TEST(EntityDecoder, NumericEntityEmptyBody) {
    // &#; 和 &#x; 空数字部分
    EXPECT_EQ(EntityDecoder::decode("&#;"), "&#;");
    EXPECT_EQ(EntityDecoder::decode("&#x;"), "&#x;");
}
