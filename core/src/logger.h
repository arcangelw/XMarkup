#pragma once

#include "xmarkup/xmarkup.h"
#include <cstdarg>

namespace xmarkup {

/**
 * @brief 内部日志工具
 *
 * 通过 XMConfig.log_callback 向宿主输出日志。
 * callback 为 NULL 时所有方法为空操作，零性能开销。
 *
 * 级别使用：
 * - ERROR: 解析异常（内存分配失败等不可恢复错误）
 * - WARN:  容错决策（隐式关闭、标签纠错、adoption agency 等）
 * - INFO:  关键决策节点（解析开始/结束）
 * - TRACE: 详细步骤（tokenizer 状态转换、CSS 标准化）
 */
class Logger {
public:
    /** @brief 初始化日志器（由 api.cpp 调用） */
    static void init(XMLogCallback callback, void* context, XMLogLevel level);

    static void error(const char* fmt, ...);
    static void warn(const char* fmt, ...);
    static void info(const char* fmt, ...);
    static void trace(const char* fmt, ...);

private:
    static void log(XMLogLevel level, const char* fmt, va_list args);

    static XMLogCallback callback_;
    static void*         context_;
    static XMLogLevel    min_level_;
};

} // namespace xmarkup
