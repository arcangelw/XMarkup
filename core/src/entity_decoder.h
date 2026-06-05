#pragma once

#include <string>
#include <string_view>

namespace xmarkup {

class EntityDecoder {
public:
    static std::string decode(std::string_view text);

private:
    static bool try_decode_entity(std::string_view text, size_t pos,
                                  size_t& entity_end, std::string& decoded);
    static bool try_named_entity(std::string_view name, std::string& decoded);
    static bool try_numeric_entity(std::string_view value, bool is_hex,
                                   std::string& decoded);
};

} // namespace xmarkup
