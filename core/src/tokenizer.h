#pragma once

#include <cstdint>
#include <string_view>
#include <vector>

namespace xmarkup {

enum class TokenType {
    TEXT,
    START_TAG,
    END_TAG,
    SELF_CLOSING_TAG,
};

enum class TokenizerState {
    DATA,
    TAG_OPEN,
    TAG_NAME,
    END_TAG_OPEN,
    BEFORE_ATTR_NAME,
    ATTR_NAME,
    AFTER_ATTR_NAME,
    ATTR_VALUE_DOUBLE_Q,
    ATTR_VALUE_SINGLE_Q,
    ATTR_VALUE_UNQUOTED,
    SELF_CLOSING,
    COMMENT,
    COMMENT_DASH1,
    COMMENT_DASH2,
    RAWTEXT,
};

struct Token {
    TokenType        type;
    std::string_view raw;
    std::string_view tag_name;
    std::string_view attributes;
};

class Tokenizer {
public:
    explicit Tokenizer(std::string_view html);

    bool has_next() const;
    Token next();

private:
    char advance();
    char peek() const;
    bool is_eof() const;
    bool is_alpha(char c) const;
    bool is_whitespace(char c) const;
    void skip_rawtext(const char* end_tag);

    std::string_view html_;
    size_t pos_ = 0;
    TokenizerState state_ = TokenizerState::DATA;
    bool has_token_ = false;
    Token pending_token_;
};

} // namespace xmarkup
