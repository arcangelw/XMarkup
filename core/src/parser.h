#pragma once

#include "xmarkup/xmarkup.h"
#include <string>
#include <vector>
#include <cstdint>

namespace xmarkup {

struct ParserInternal {
    XMConfig config;
    XMError last_error = XM_OK;

    XMResult* parse(const char* html, size_t length);

private:
    std::string owned_text_;
    std::vector<XMSpan> owned_spans_;
    std::vector<std::string> owned_values_;
};

} // namespace xmarkup
