#include "tokenizer.h"
#include <cctype>

namespace xmarkup {

Tokenizer::Tokenizer(std::string_view html)
    : html_(html), pos_(0), state_(TokenizerState::DATA), has_token_(false) {}

bool Tokenizer::has_next() const {
    return has_token_ || pos_ < html_.size();
}

Token Tokenizer::next() {
    // 如果有缓存的 token，直接返回
    if (has_token_) {
        has_token_ = false;
        return pending_token_;
    }

    if (is_eof()) return {TokenType::TEXT, {}, {}, {}};

    // 运行状态机直到产出一个 token
    while (pos_ < html_.size() || state_ != TokenizerState::DATA) {
        switch (state_) {

        case TokenizerState::DATA: {
            // 在 DATA 状态下收集文本直到遇到 '<'
            size_t text_start = pos_;
            while (pos_ < html_.size() && html_[pos_] != '<') {
                pos_++;
            }
            if (pos_ > text_start) {
                // 有累积的文本，先返回 TEXT token
                Token tok;
                tok.type = TokenType::TEXT;
                tok.raw = html_.substr(text_start, pos_ - text_start);
                // 不改变 state_，下次进来还是 DATA（或 pos_ 到达 '<'）
                if (pos_ < html_.size() && html_[pos_] == '<') {
                    // 下次要从 '<' 开始处理标签
                    // 用 state_ 标记：下次先处理 TAG_OPEN
                    state_ = TokenizerState::TAG_OPEN;
                }
                return tok;
            }
            // pos_ 指向 '<'，转入 TAG_OPEN
            state_ = TokenizerState::TAG_OPEN;
            break;
        }

        case TokenizerState::TAG_OPEN: {
            // pos_ 指向 '<'
            if (pos_ >= html_.size() || html_[pos_] != '<') {
                // 不应该到这里，重置
                state_ = TokenizerState::DATA;
                break;
            }
            pos_++; // 消费 '<'

            if (pos_ >= html_.size()) {
                // '<' 在末尾，当作文本
                Token tok;
                tok.type = TokenType::TEXT;
                tok.raw = "<";
                state_ = TokenizerState::DATA;
                return tok;
            }

            char next = html_[pos_];
            if (next == '/') {
                pos_++;
                state_ = TokenizerState::END_TAG_OPEN;
            } else if (next == '!') {
                pos_++;
                state_ = TokenizerState::COMMENT;
            } else if (is_alpha(next)) {
                state_ = TokenizerState::TAG_NAME;
            } else {
                // '<' 后不是合法标签名字符，当作文本
                Token tok;
                tok.type = TokenType::TEXT;
                tok.raw = "<";
                state_ = TokenizerState::DATA;
                return tok;
            }
            break;
        }

        case TokenizerState::END_TAG_OPEN: {
            // 消费了 '</'，期望标签名
            if (pos_ >= html_.size() || !is_alpha(html_[pos_])) {
                // '</' 后没有合法标签名，当作文本
                Token tok;
                tok.type = TokenType::TEXT;
                tok.raw = "</";
                state_ = TokenizerState::DATA;
                return tok;
            }
            state_ = TokenizerState::TAG_NAME;
            break;
        }

        case TokenizerState::TAG_NAME: {
            // 读取标签名
            size_t name_start = pos_;
            while (pos_ < html_.size() && !is_whitespace(html_[pos_]) &&
                   html_[pos_] != '>' && html_[pos_] != '/') {
                pos_++;
            }
            std::string_view tag_name = html_.substr(name_start, pos_ - name_start);
            if (tag_name.empty()) {
                state_ = TokenizerState::DATA;
                break;
            }

            // 记录属性区域的起始（紧跟标签名之后）
            size_t attr_start = pos_;
            state_ = TokenizerState::BEFORE_ATTR_NAME;

            // 继续处理属性，直到遇到 '>' 或 '/>'
            while (pos_ < html_.size()) {
                char c = html_[pos_];

                switch (state_) {
                case TokenizerState::BEFORE_ATTR_NAME:
                    if (is_whitespace(c)) {
                        pos_++;
                    } else if (c == '>') {
                        goto emit_tag_token;
                    } else if (c == '/') {
                        pos_++;
                        state_ = TokenizerState::SELF_CLOSING;
                    } else {
                        state_ = TokenizerState::ATTR_NAME;
                        pos_++;
                    }
                    break;

                case TokenizerState::SELF_CLOSING:
                    if (c == '>') {
                        goto emit_tag_token;
                    } else {
                        state_ = TokenizerState::BEFORE_ATTR_NAME;
                    }
                    break;

                case TokenizerState::ATTR_NAME:
                    if (c == '=') {
                        pos_++;
                        if (pos_ < html_.size()) {
                            char qc = html_[pos_];
                            if (qc == '"') {
                                state_ = TokenizerState::ATTR_VALUE_DOUBLE_Q;
                                pos_++;
                            } else if (qc == '\'') {
                                state_ = TokenizerState::ATTR_VALUE_SINGLE_Q;
                                pos_++;
                            } else {
                                state_ = TokenizerState::ATTR_VALUE_UNQUOTED;
                            }
                        }
                    } else if (is_whitespace(c)) {
                        pos_++;
                        state_ = TokenizerState::AFTER_ATTR_NAME;
                    } else if (c == '>' || c == '/') {
                        state_ = TokenizerState::BEFORE_ATTR_NAME;
                    } else {
                        pos_++;
                    }
                    break;

                case TokenizerState::AFTER_ATTR_NAME:
                    if (is_whitespace(c)) {
                        pos_++;
                    } else if (c == '=') {
                        pos_++;
                        if (pos_ < html_.size()) {
                            char qc = html_[pos_];
                            if (qc == '"') {
                                state_ = TokenizerState::ATTR_VALUE_DOUBLE_Q;
                                pos_++;
                            } else if (qc == '\'') {
                                state_ = TokenizerState::ATTR_VALUE_SINGLE_Q;
                                pos_++;
                            } else {
                                state_ = TokenizerState::ATTR_VALUE_UNQUOTED;
                            }
                        }
                    } else if (c == '>' || c == '/') {
                        state_ = TokenizerState::BEFORE_ATTR_NAME;
                    } else {
                        state_ = TokenizerState::ATTR_NAME;
                        pos_++;
                    }
                    break;

                case TokenizerState::ATTR_VALUE_DOUBLE_Q:
                    if (c == '"') {
                        pos_++;
                        state_ = TokenizerState::BEFORE_ATTR_NAME;
                    } else {
                        pos_++;
                    }
                    break;

                case TokenizerState::ATTR_VALUE_SINGLE_Q:
                    if (c == '\'') {
                        pos_++;
                        state_ = TokenizerState::BEFORE_ATTR_NAME;
                    } else {
                        pos_++;
                    }
                    break;

                case TokenizerState::ATTR_VALUE_UNQUOTED:
                    if (is_whitespace(c) || c == '>') {
                        state_ = TokenizerState::BEFORE_ATTR_NAME;
                    } else {
                        pos_++;
                    }
                    break;

                default:
                    pos_++;
                    break;
                }
            }
            // 到达 EOF 但标签未闭合
            {
                // 回溯找到 '<' 的位置
                size_t lt_pos = name_start;
                while (lt_pos > 0 && html_[lt_pos - 1] != '<') lt_pos--;
                if (lt_pos > 0) lt_pos--; // 指向 '<'

                bool is_end_tag = (lt_pos + 1 < html_.size() && html_[lt_pos + 1] == '/');
                std::string_view raw = html_.substr(lt_pos);
                std::string_view attrs = html_.substr(attr_start);

                Token tok;
                tok.type = is_end_tag ? TokenType::END_TAG : TokenType::START_TAG;
                tok.raw = raw;
                tok.tag_name = tag_name;
                // 清理前导空白
                while (!attrs.empty() && is_whitespace(attrs.front())) attrs.remove_prefix(1);
                tok.attributes = attrs.empty() ? std::string_view{} : attrs;
                state_ = TokenizerState::DATA;
                pos_ = html_.size();
                return tok;
            }

        emit_tag_token:
            // pos_ 指向 '>'
            {
                size_t lt_pos = name_start;
                while (lt_pos > 0 && html_[lt_pos - 1] != '<') lt_pos--;
                if (lt_pos > 0) lt_pos--;

                bool is_end_tag = (lt_pos + 1 < html_.size() && html_[lt_pos + 1] == '/');
                bool is_self_closing = (state_ == TokenizerState::SELF_CLOSING);

                std::string_view raw = html_.substr(lt_pos, pos_ - lt_pos + 1);

                // 属性区域：从 attr_start 到 pos_（或 pos_-1 如果 self_closing）
                size_t attr_end = is_self_closing ? pos_ - 1 : pos_;
                std::string_view attrs;
                if (attr_end > attr_start) {
                    attrs = html_.substr(attr_start, attr_end - attr_start);
                }
                while (!attrs.empty() && is_whitespace(attrs.front())) attrs.remove_prefix(1);

                pos_++; // 消费 '>'

                // 处理 RAWTEXT 标签（script/style/noscript）——完全吞掉，不产出 token
                if (!is_end_tag && !is_self_closing &&
                    (tag_name == "script" || tag_name == "style" || tag_name == "noscript")) {
                    if (tag_name == "script") skip_rawtext("script");
                    else if (tag_name == "style") skip_rawtext("style");
                    else skip_rawtext("noscript");
                    state_ = TokenizerState::DATA;
                    break; // 跳出 TAG_NAME switch，继续外层 while 循环
                }

                Token tok;
                if (is_self_closing) {
                    tok.type = TokenType::SELF_CLOSING_TAG;
                } else if (is_end_tag) {
                    tok.type = TokenType::END_TAG;
                } else {
                    tok.type = TokenType::START_TAG;
                }
                tok.raw = raw;
                tok.tag_name = tag_name;
                tok.attributes = attrs.empty() ? std::string_view{} : attrs;
                state_ = TokenizerState::DATA;
                return tok;
            }
        }

        case TokenizerState::COMMENT: {
            // 消费了 '<!'，期望注释或声明
            // 检查是否是 <!-- 注释
            if (pos_ < html_.size() && html_[pos_] == '-') {
                pos_++;
                if (pos_ < html_.size() && html_[pos_] == '-') {
                    pos_++;
                    // 确认是 <!-- 注释，跳过到 -->
                    while (pos_ + 2 < html_.size()) {
                        if (html_[pos_] == '-' && html_[pos_ + 1] == '-' && html_[pos_ + 2] == '>') {
                            pos_ += 3;
                            break;
                        }
                        pos_++;
                    }
                    // 如果没找到 -->，跳到末尾
                    if (pos_ + 2 >= html_.size() && !(pos_ + 2 < html_.size())) {
                        pos_ = html_.size();
                    }
                    state_ = TokenizerState::DATA;
                    break;
                }
                // <!- 不是注释开始，当作声明处理，跳过到 >
            }
            // 其他声明（如 <!DOCTYPE>），跳过到 >
            while (pos_ < html_.size() && html_[pos_] != '>') {
                pos_++;
            }
            if (pos_ < html_.size()) pos_++; // 消费 '>'
            state_ = TokenizerState::DATA;
            break;
        }

        case TokenizerState::COMMENT_DASH1:
        case TokenizerState::COMMENT_DASH2:
            // 这两个状态在重构后不再需要，注释处理在 COMMENT 中完成
            state_ = TokenizerState::DATA;
            break;

        case TokenizerState::RAWTEXT:
            // RAWTEXT 状态在重构后由 skip_rawtext 直接处理
            state_ = TokenizerState::DATA;
            break;

        default:
            state_ = TokenizerState::DATA;
            break;
        }
    }

    // 不应到达此处
    return {TokenType::TEXT, {}, {}, {}};
}

char Tokenizer::advance() {
    if (pos_ >= html_.size()) return '\0';
    return html_[pos_++];
}

char Tokenizer::peek() const {
    if (pos_ >= html_.size()) return '\0';
    return html_[pos_];
}

bool Tokenizer::is_eof() const {
    return pos_ >= html_.size();
}

bool Tokenizer::is_alpha(char c) const {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
}

bool Tokenizer::is_whitespace(char c) const {
    return c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\f';
}

void Tokenizer::skip_rawtext(const char* end_tag) {
    std::string close_tag = "</";
    close_tag += end_tag;
    auto close_len = close_tag.size();

    while (pos_ + close_len <= html_.size()) {
        bool match = true;
        for (size_t i = 0; i < close_len && match; i++) {
            char a = static_cast<char>(std::tolower(static_cast<unsigned char>(close_tag[i])));
            char b = static_cast<char>(std::tolower(static_cast<unsigned char>(html_[pos_ + i])));
            if (a != b) match = false;
        }
        if (match) {
            // 跳过闭合标签名
            pos_ += close_len;
            // 跳过空白和 '>'
            while (pos_ < html_.size() && html_[pos_] != '>') pos_++;
            if (pos_ < html_.size()) pos_++;
            return;
        }
        pos_++;
    }
    pos_ = html_.size();
}

} // namespace xmarkup
