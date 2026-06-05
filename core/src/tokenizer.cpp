#include "tokenizer.h"

namespace xmarkup {

Tokenizer::Tokenizer(std::string_view html) : html_(html), pos_(0), token_start_(0), state_(TokenizerState::DATA) {}

bool Tokenizer::has_next() const { (void)state_; (void)pos_; (void)token_start_; return false; }
Token Tokenizer::next() { return Token{}; }

char Tokenizer::advance() { return '\0'; }
char Tokenizer::peek() const { return '\0'; }
bool Tokenizer::is_eof() const { return true; }
bool Tokenizer::is_alpha(char) const { return false; }
bool Tokenizer::is_whitespace(char) const { return false; }
void Tokenizer::skip_rawtext(const char*) {}
void Tokenizer::emit_text() {}
void Tokenizer::start_token() {}

} // namespace xmarkup
