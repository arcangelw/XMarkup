#pragma once

#include "xmarkup/xmarkup.h"
#include <string>
#include <vector>
#include <cstdint>

namespace xmarkup {

/**
 * @brief 解析器内部实现
 *
 * 封装完整的解析管线（词法分析 → AST → 样式解析 → UTF-16 映射），
 * 管理 XMResult 中 text/spans/value 的底层存储。
 *
 * 生命周期：由 xmarkup_create() 创建，xmarkup_destroy() 销毁。
 *
 * @warning XMResult 中的 text/spans 指针指向此对象的 owned_* 成员，
 *          下次调用 parse() 会覆盖这些数据。因此 XMResult 的有效期
 *          仅到下一次 parse() 调用为止。
 */
struct ParserInternal {
    XMConfig config;             /**< 解析器配置 */
    XMError last_error = XM_OK;  /**< 最近一次解析的错误码 */

    /**
     * @brief 执行完整解析管线
     *
     * 流程：词法分析 → AST 构建 → 样式解析 → UTF-16 索引映射 → 组装 XMResult
     *
     * @param html   HTML 输入（UTF-8），不需要以 \0 结尾
     * @param length 输入字节长度
     * @return 解析结果指针，失败返回 nullptr（检查 last_error）
     *
     * @warning 返回的 XMResult* 内部指针在下次 parse() 调用前有效
     */
    XMResult* parse(const char* html, size_t length);

private:
    std::string owned_text_;          /**< 拥有的文本数据（XMResult.text 指向此） */
    std::vector<XMSpan> owned_spans_; /**< 拥有的 span 数组（XMResult.spans 指向此） */
    std::vector<std::string> owned_values_; /**< 拥有的 value 字符串（XMSpan.value 指向此） */
};

} // namespace xmarkup
