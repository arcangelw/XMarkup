#include "tokenizer.h"
#include <cctype>

namespace xmarkup {

Tokenizer::Tokenizer(std::string_view html)
    : html_(html), pos_(0), state_(TokenizerState::DATA), has_token_(false) {}

bool Tokenizer::has_next() const {
    return has_token_ || pos_ < html_.size();
}

Token Tokenizer::next() {
    // 返回缓存的 token（由状态机提前产出但未返回的情况）
    if (has_token_) {
        has_token_ = false;
        return pending_token_;
    }

    if (is_eof()) return {TokenType::TEXT, {}, {}, {}};

    // 运行状态机直到产出一个 token
    while (pos_ < html_.size() || state_ != TokenizerState::DATA) {
        switch (state_) {

        // === DATA 状态：收集纯文本直到遇到 '<' ===
        case TokenizerState::DATA: {
            size_t text_start = pos_;
            while (pos_ < html_.size() && html_[pos_] != '<') {
                pos_++;
            }
            if (pos_ > text_start) {
                // 累积了文本内容，产出 TEXT token
                Token tok;
                tok.type = TokenType::TEXT;
                tok.raw = html_.substr(text_start, pos_ - text_start);
                if (pos_ < html_.size() && html_[pos_] == '<') {
                    // 标记下次从 TAG_OPEN 开始处理标签
                    state_ = TokenizerState::TAG_OPEN;
                }
                return tok;
            }
            // pos_ 指向 '<'，转入 TAG_OPEN
            state_ = TokenizerState::TAG_OPEN;
            break;
        }

        // === TAG_OPEN 状态：消费 '<'，判断标签方向 ===
        case TokenizerState::TAG_OPEN: {
            if (pos_ >= html_.size() || html_[pos_] != '<') {
                state_ = TokenizerState::DATA;
                break;
            }
            pos_++; // 消费 '<'

            if (pos_ >= html_.size()) {
                // '<' 在末尾，当作普通文本
                Token tok;
                tok.type = TokenType::TEXT;
                tok.raw = "<";
                state_ = TokenizerState::DATA;
                return tok;
            }

            char next = html_[pos_];
            if (next == '/') {
                pos_++;
                state_ = TokenizerState::END_TAG_OPEN;   // 结束标签
            } else if (next == '!') {
                pos_++;
                state_ = TokenizerState::COMMENT;         // 注释或声明
            } else if (is_alpha(next)) {
                state_ = TokenizerState::TAG_NAME;        // 开始标签
            } else {
                // '<' 后不是合法标签名字符，当作普通文本 '<'
                Token tok;
                tok.type = TokenType::TEXT;
                tok.raw = "<";
                state_ = TokenizerState::DATA;
                return tok;
            }
            break;
        }

        // === END_TAG_OPEN 状态：已消费 '</'，验证标签名合法性 ===
        case TokenizerState::END_TAG_OPEN: {
            if (pos_ >= html_.size() || !is_alpha(html_[pos_])) {
                // '</' 后不是字母，当作文本 "</"
                Token tok;
                tok.type = TokenType::TEXT;
                tok.raw = "</";
                state_ = TokenizerState::DATA;
                return tok;
            }
            state_ = TokenizerState::TAG_NAME;
            break;
        }

        // === TAG_NAME 状态：读取标签名 + 属性，直到 '>' 或 '/>' ===
        // 这是最大的状态，内含属性解析子状态机
        case TokenizerState::TAG_NAME: {
            // 读取标签名（到空白、'>' 或 '/' 为止）
            size_t name_start = pos_;
            while (pos_ < html_.size() && !is_whitespace(html_[pos_]) &&
                   html_[pos_] != '>' && html_[pos_] != '/') {
                pos_++;
            }
            std::string_view raw_tag = html_.substr(name_start, pos_ - name_start);
            if (raw_tag.empty()) {
                state_ = TokenizerState::DATA;
                break;
            }

            // 小写化标签名（HTML 标签名不区分大小写）
            std::string tag_lower;
            tag_lower.reserve(raw_tag.size());
            for (char c : raw_tag) {
                tag_lower += static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
            }

            // 属性区域起始位置（紧跟标签名之后）
            size_t attr_start = pos_;
            state_ = TokenizerState::BEFORE_ATTR_NAME;

            // 属性解析子状态机：循环直到遇到 '>' 或 '/>'
            while (pos_ < html_.size()) {
                char c = html_[pos_];

                switch (state_) {

                // BEFORE_ATTR_NAME：等待属性名或标签结束符
                case TokenizerState::BEFORE_ATTR_NAME:
                    if (is_whitespace(c)) {
                        pos_++;
                    } else if (c == '>') {
                        goto emit_tag_token;     // 标签结束
                    } else if (c == '/') {
                        pos_++;
                        state_ = TokenizerState::SELF_CLOSING;  // 可能是自闭合
                    } else {
                        state_ = TokenizerState::ATTR_NAME;     // 开始属性名
                        pos_++;
                    }
                    break;

                // SELF_CLOSING：已读 '/'，期望 '>' 确认自闭合
                case TokenizerState::SELF_CLOSING:
                    if (c == '>') {
                        goto emit_tag_token;     // 确认自闭合
                    } else {
                        // '/' 后不是 '>'，回退（HTML 容错）
                        state_ = TokenizerState::BEFORE_ATTR_NAME;
                    }
                    break;

                // ATTR_NAME：读取属性名，等待 '=' 或空白
                case TokenizerState::ATTR_NAME:
                    if (c == '=') {
                        pos_++;
                        // '=' 后根据引号类型选择属性值状态
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

                // AFTER_ATTR_NAME：属性名后等待 '=' 或下一个属性
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
                        // 不是 '='，当作新属性名开始（HTML 容错：布尔属性后跟新属性）
                        state_ = TokenizerState::ATTR_NAME;
                        pos_++;
                    }
                    break;

                // ATTR_VALUE_DOUBLE_Q：读取双引号属性值，直到遇到结束双引号
                case TokenizerState::ATTR_VALUE_DOUBLE_Q:
                    if (c == '"') {
                        pos_++;
                        state_ = TokenizerState::BEFORE_ATTR_NAME;  // 属性值结束
                    } else {
                        pos_++;  // 属性值内的内容（包括 '<'、'&' 等原样保留）
                    }
                    break;

                // ATTR_VALUE_SINGLE_Q：读取单引号属性值，直到遇到结束单引号
                case TokenizerState::ATTR_VALUE_SINGLE_Q:
                    if (c == '\'') {
                        pos_++;
                        state_ = TokenizerState::BEFORE_ATTR_NAME;
                    } else {
                        pos_++;
                    }
                    break;

                // ATTR_VALUE_UNQUOTED：读取无引号属性值，到空白或 '>' 结束
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

            // 到达 EOF 但标签未闭合——回退将未闭合标签当作 token 产出
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
                tok.tag_name = std::move(tag_lower);
                // 清理属性字符串前导空白
                while (!attrs.empty() && is_whitespace(attrs.front())) attrs.remove_prefix(1);
                tok.attributes = attrs.empty() ? std::string_view{} : attrs;
                state_ = TokenizerState::DATA;
                pos_ = html_.size();
                return tok;
            }

        emit_tag_token:
            // pos_ 指向 '>'，组装完整的标签 token
            {
                size_t lt_pos = name_start;
                while (lt_pos > 0 && html_[lt_pos - 1] != '<') lt_pos--;
                if (lt_pos > 0) lt_pos--;

                bool is_end_tag = (lt_pos + 1 < html_.size() && html_[lt_pos + 1] == '/');
                bool is_self_closing = (state_ == TokenizerState::SELF_CLOSING);

                std::string_view raw = html_.substr(lt_pos, pos_ - lt_pos + 1);

                // 属性区域：从 attr_start 到 '>' 之前（自闭合时到 '/' 之前）
                size_t attr_end = is_self_closing ? pos_ - 1 : pos_;
                std::string_view attrs;
                if (attr_end > attr_start) {
                    attrs = html_.substr(attr_start, attr_end - attr_start);
                }
                while (!attrs.empty() && is_whitespace(attrs.front())) attrs.remove_prefix(1);

                pos_++; // 消费 '>'

                // 处理 RAWTEXT 标签（script/style/noscript）——整体跳过内容，不产出 token
                // 这是 HTML5 规范要求的特殊行为：这些标签的内容不是 HTML
                if (!is_end_tag && !is_self_closing &&
                    (tag_lower == "script" || tag_lower == "style" || tag_lower == "noscript")) {
                    if (tag_lower == "script") skip_rawtext("script");
                    else if (tag_lower == "style") skip_rawtext("style");
                    else skip_rawtext("noscript");
                    state_ = TokenizerState::DATA;
                    break; // 跳出 TAG_NAME，继续外层 while 寻找下一个 token
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
                tok.tag_name = std::move(tag_lower);
                tok.attributes = attrs.empty() ? std::string_view{} : attrs;
                state_ = TokenizerState::DATA;
                return tok;
            }
        }

        // === COMMENT 状态：处理 HTML 注释（<!-- -->）和声明（<!DOCTYPE>） ===
        case TokenizerState::COMMENT: {
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
                    // 未找到 --> 则跳到末尾（容错）
                    if (pos_ + 2 >= html_.size()) {
                        pos_ = html_.size();
                    }
                    state_ = TokenizerState::DATA;
                    break;
                }
                // <!- 不是注释开始，当作声明处理
            }
            // 其他声明（如 <!DOCTYPE>），跳过到 '>'
            while (pos_ < html_.size() && html_[pos_] != '>') {
                pos_++;
            }
            if (pos_ < html_.size()) pos_++; // 消费 '>'
            state_ = TokenizerState::DATA;
            break;
        }

        default:
            state_ = TokenizerState::DATA;
            break;
        }
    }

    return {TokenType::TEXT, {}, {}, {}};
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

/**
 * @brief 跳过 RAWTEXT 内容（script/style/noscript 标签体）
 *
 * 这些标签的内容不是 HTML，需要整体跳过直到对应的闭合标签。
 * 匹配时不区分大小写。
 *
 * @param end_tag 闭合标签名（如 "script"）
 */
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
            pos_ += close_len;
            // 跳过闭合标签名后的空白和 '>'
            while (pos_ < html_.size() && html_[pos_] != '>') pos_++;
            if (pos_ < html_.size()) pos_++;
            return;
        }
        pos_++;
    }
    pos_ = html_.size();
}

} // namespace xmarkup
