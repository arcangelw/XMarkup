#include "entity_decoder.h"

namespace xmarkup {

std::string EntityDecoder::decode(std::string_view text) { return std::string(text); }

bool EntityDecoder::try_decode_entity(std::string_view, size_t, size_t&, std::string&) {
    return false;
}
bool EntityDecoder::try_named_entity(std::string_view, std::string&) { return false; }
bool EntityDecoder::try_numeric_entity(std::string_view, bool, std::string&) { return false; }

} // namespace xmarkup
