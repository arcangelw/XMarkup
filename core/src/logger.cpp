#include "logger.h"
#include <cstdio>

namespace xmarkup {

XMLogCallback Logger::callback_  = nullptr;
void*         Logger::context_   = nullptr;
XMLogLevel    Logger::min_level_ = XM_LOG_ERROR;

void Logger::init(XMLogCallback callback, void* context, XMLogLevel level) {
    callback_  = callback;
    context_   = context;
    min_level_ = level;
}

void Logger::log(XMLogLevel level, const char* fmt, va_list args) {
    if (!callback_ || level > min_level_) return;

    char buf[1024];
    std::vsnprintf(buf, sizeof(buf), fmt, args);
    callback_(level, buf, context_);
}

void Logger::error(const char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    log(XM_LOG_ERROR, fmt, args);
    va_end(args);
}

void Logger::warn(const char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    log(XM_LOG_WARN, fmt, args);
    va_end(args);
}

void Logger::info(const char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    log(XM_LOG_INFO, fmt, args);
    va_end(args);
}

void Logger::trace(const char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    log(XM_LOG_TRACE, fmt, args);
    va_end(args);
}

} // namespace xmarkup
