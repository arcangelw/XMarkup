#ifndef XMARKUP_H
#define XMARKUP_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief HTML 标签类型枚举
 *
 * 将 HTML 标签映射为语义化的整数值，语义等价的标签共享同一值
 * （如 <b> 和 <strong> 都映射为 XM_TAG_BOLD）。
 *
 * 值域分组：0 = 未知, 1-9 = 文本样式, 20-29 = 段落结构,
 * 40-49 = 链接与媒体, 50-59 = 列表, 60-69 = 表格, 70+ = 其他
 */
typedef enum XMTagType {
    XM_TAG_UNKNOWN       = 0,   /**< 未识别的标签 */

    /* 文本样式 */
    XM_TAG_BOLD          = 1,   /**< 加粗（<b>, <strong>） */
    XM_TAG_ITALIC        = 2,   /**< 斜体（<i>, <em>） */
    XM_TAG_UNDERLINE     = 3,   /**< 下划线（<u>） */
    XM_TAG_STRIKETHROUGH = 4,   /**< 删除线（<s>, <strike>, <del>） */
    XM_TAG_SUBSCRIPT     = 5,   /**< 下标（<sub>） */
    XM_TAG_SUPERSCRIPT   = 6,   /**< 上标（<sup>） */
    XM_TAG_MARK          = 7,   /**< 高亮标记（<mark>） */
    XM_TAG_CODE          = 8,   /**< 行内代码（<code>） */

    /* 段落结构 */
    XM_TAG_PARAGRAPH     = 20,  /**< 段落（<p>） */
    XM_TAG_HEADING_1     = 21,  /**< 一级标题（<h1>） */
    XM_TAG_HEADING_2     = 22,  /**< 二级标题（<h2>） */
    XM_TAG_HEADING_3     = 23,  /**< 三级标题（<h3>） */
    XM_TAG_HEADING_4     = 24,  /**< 四级标题（<h4>） */
    XM_TAG_HEADING_5     = 25,  /**< 五级标题（<h5>） */
    XM_TAG_HEADING_6     = 26,  /**< 六级标题（<h6>） */
    XM_TAG_BLOCKQUOTE    = 27,  /**< 引用块（<blockquote>） */
    XM_TAG_PREFORMATTED  = 28,  /**< 预格式化（<pre>），内部空白保留 */

    /* 链接与媒体 */
    XM_TAG_LINK          = 40,  /**< 超链接（<a>），value 存放 href */
    XM_TAG_IMAGE         = 41,  /**< 图片（<img>），value 存放 src，文本中插入 U+FFFC 占位 */
    XM_TAG_VIDEO         = 42,  /**< 视频（<video>），文本中插入 U+FFFC 占位 */
    XM_TAG_VIDEO_SOURCE  = 43,  /**< 视频源（<source> 在 <video> 内），value 存放 src */
    XM_TAG_AUDIO         = 44,  /**< 音频（<audio>），文本中插入 U+FFFC 占位 */
    XM_TAG_AUDIO_SOURCE  = 45,  /**< 音频源（<source> 在 <audio> 内），value 存放 src */

    /* 列表 */
    XM_TAG_LIST_ORDERED   = 50,  /**< 有序列表（<ol>） */
    XM_TAG_LIST_UNORDERED = 51,  /**< 无序列表（<ul>） */
    XM_TAG_LIST_ITEM      = 52,  /**< 列表项（<li>） */

    /* 表格 */
    XM_TAG_TABLE         = 60,  /**< 表格（<table>） */
    XM_TAG_TABLE_ROW     = 61,  /**< 表格行（<tr>） */
    XM_TAG_TABLE_CELL    = 62,  /**< 表格单元格（<td>） */
    XM_TAG_TABLE_HEADER  = 63,  /**< 表头单元格（<th>） */

    /* 其他 */
    XM_TAG_HORIZONTAL_RULE = 70, /**< 水平线（<hr>），文本中插入 U+FFFC 占位 */
    XM_TAG_LINE_BREAK    = 71,  /**< 换行（<br>），文本中插入 \n */
    XM_TAG_DIVISION      = 72,  /**< 通用容器（<div>） */
    XM_TAG_SPAN          = 73,  /**< 行内容器（<span>） */
} XMTagType;

/**
 * @brief CSS 样式属性类型枚举
 *
 * 对应内联 style 属性中的 CSS 属性，值存储在 XMSpan.value 中。
 */
typedef enum XMStyleType {
    XM_STYLE_FOREGROUND_COLOR = 1,  /**< 前景色（color），值格式 "#RRGGBB" */
    XM_STYLE_BACKGROUND_COLOR = 2,  /**< 背景色（background-color），值格式 "#RRGGBB" */
    XM_STYLE_FONT_SIZE        = 3,  /**< 字号（font-size），值格式 "16"/"21.75"（px 数字字符串） */
    XM_STYLE_FONT_WEIGHT      = 4,  /**< 字重（font-weight），值格式 "bold"/"700" */
    XM_STYLE_FONT_STYLE       = 5,  /**< 字体样式（font-style），值格式 "italic" */
    XM_STYLE_TEXT_DECORATION   = 6,  /**< 文本装饰（text-decoration） */
    XM_STYLE_LINE_HEIGHT      = 7,  /**< 行高（line-height） */
    XM_STYLE_TEXT_ALIGN       = 8,  /**< 文本对齐（text-align） */
    XM_STYLE_LETTER_SPACING   = 9,  /**< 字间距（letter-spacing） */
    XM_STYLE_MEDIA_TYPE       = 10, /**< 媒体类型（<source> 的 type 属性） */
    XM_STYLE_MEDIA_QUERY      = 11, /**< 媒体查询（<source> 的 media 属性） */
} XMStyleType;

/**
 * @brief 错误码枚举
 */
typedef enum XMError {
    XM_OK                   = 0,  /**< 成功 */
    XM_ERR_NULL_PARSER      = -1, /**< 解析器指针为 NULL */
    XM_ERR_NULL_INPUT       = -2, /**< 输入 HTML 为 NULL */
    XM_ERR_NESTING_OVERFLOW = -3, /**< 嵌套深度超限，已截断 */
    XM_ERR_ALLOC_FAILED     = -4, /**< 内存分配失败 */
} XMError;

/**
 * @brief UTF-16 文本区间
 *
 * 表示 span 在解析结果文本中的起止位置，使用 UTF-16 编码单元索引。
 * 适用于 iOS (NSString length) / Android (CharSequence) 等平台的文本定位。
 */
typedef struct XMRange {
    uint32_t start; /**< 区间起始（含），UTF-16 索引 */
    uint32_t end;   /**< 区间结束（不含），UTF-16 索引 */
} XMRange;

/**
 * @brief 样式区间单元
 *
 * 描述一段文本上的标签类型和/或 CSS 样式属性。
 * 每个 span 至少有 tag 或 style 之一非零。
 * tag span 和 style span 可能覆盖相同的文本范围。
 */
typedef struct XMSpan {
    XMRange     range;     /**< 文本范围（UTF-16 索引） */
    XMTagType   tag;       /**< HTML 标签类型，0 表示无标签 */
    XMStyleType style;     /**< CSS 样式属性类型，0 表示无样式 */
    const char* value;     /**< 属性/样式值字符串（如 href、颜色值），可为 NULL */
    uint32_t    value_len; /**< value 的字节长度（不含终止符） */
} XMSpan;

/**
 * @brief 解析结果
 *
 * 包含解析后的纯文本和所有样式区间。
 *
 * @warning text 和 spans 指针指向解析器内部数据，在下一次调用
 *          xmarkup_parse() 之前有效。如需长期持有，请复制数据。
 *          调用 xmarkup_result_free() 释放 result 本身。
 *
 * @code
 * XMResult* result = xmarkup_parse(parser, "<b>Hello</b>", 13);
 * if (result && result->error == XM_OK) {
 *     printf("text: %.*s\n", result->text_len, result->text);
 *     for (uint32_t i = 0; i < result->span_count; i++) {
 *         printf("span[%u]: tag=%d [%u, %u)\n", i,
 *                result->spans[i].tag,
 *                result->spans[i].range.start,
 *                result->spans[i].range.end);
 *     }
 * }
 * xmarkup_result_free(result);
 * @endcode
 */
typedef struct XMResult {
    XMError       error;      /**< 错误码，XM_OK 表示成功 */
    const char*   text;       /**< 解析后的纯文本（UTF-8 编码） */
    uint32_t      text_len;   /**< text 的字节长度（不含终止符） */
    const XMSpan* spans;      /**< 样式区间数组 */
    uint32_t      span_count; /**< spans 数组长度 */
} XMResult;

/**
 * @brief 解析器配置
 *
 * @code
 * XMConfig cfg = {1, 256, 16.0f};  // 启用纠错, 最大嵌套 256, 基准字号 16px
 * XMParser* parser = xmarkup_create(&cfg);
 * // 或使用默认配置：
 * XMParser* parser = xmarkup_create(NULL);
 * @endcode
 */
typedef struct XMConfig {
    uint8_t  enable_autocorrect; /**< 是否启用自动纠错（处理未闭合/错嵌套标签） */
    uint16_t max_nesting_depth;  /**< 最大标签嵌套深度，防止恶意输入，默认 256 */
    float    base_font_size;     /**< 基准字号（px），支持浮点精度，用于 em/rem/% 换算 */
} XMConfig;

/** 不透明解析器句柄，内部实现细节不暴露 */
typedef struct XMParser XMParser;

/**
 * @brief 创建 XMarkup 解析器实例
 *
 * @param config 配置参数，传 NULL 使用默认值
 *               {enable_autocorrect=1, max_nesting_depth=256, base_font_size=16.0f}。
 *               调用者不需要释放 config。
 * @return 解析器指针，内存不足时返回 NULL
 * @note 返回的指针必须通过 xmarkup_destroy() 释放
 *
 * @code
 * XMParser* parser = xmarkup_create(NULL);
 * XMResult* result = xmarkup_parse(parser, "<b>Hello</b>", 13);
 * xmarkup_result_free(result);
 * xmarkup_destroy(parser);
 * @endcode
 *
 * @see xmarkup_destroy, XMConfig
 */
XMParser* xmarkup_create(const XMConfig* config);

/**
 * @brief 销毁解析器实例，释放所有资源
 *
 * @param parser 解析器指针，传 NULL 为安全空操作
 * @note 销毁后，所有由此解析器产出的 XMResult 将失效（text/spans 指针悬空）。
 *       请确保先释放所有 XMResult，再销毁解析器。
 *
 * @see xmarkup_create
 */
void xmarkup_destroy(XMParser* parser);

/**
 * @brief 解析 HTML 片段
 *
 * 执行完整解析管线：词法分析 → AST 构建 → 样式解析 → 实体解码 → UTF-16 索引映射。
 *
 * @param parser 解析器实例
 * @param html   HTML 输入字符串（UTF-8 编码，不需要以 \0 结尾）
 * @param length html 的字节长度
 * @return 解析结果指针，错误时返回 NULL（调用 xmarkup_last_error 获取原因）
 *
 * @warning 返回的 XMResult* 在下次调用 xmarkup_parse() 之前有效。
 *          如需跨多次 parse 调用持有数据，请自行复制。
 *
 * @code
 * const char* html = "<b>Hello</b> <i>World</i>";
 * XMResult* r = xmarkup_parse(parser, html, strlen(html));
 * if (r) {
 *     // 使用 r->text, r->spans ...
 *     xmarkup_result_free(r);
 * }
 * @endcode
 *
 * @see xmarkup_result_free, XMResult
 */
XMResult* xmarkup_parse(XMParser* parser, const char* html, size_t length);

/**
 * @brief 释放解析结果
 *
 * @param result 解析结果指针，传 NULL 为安全空操作
 * @note 由于 XMResult 中的 text/spans 指向解析器内部数据，
 *       此函数仅释放 result 结构体本身，内部数据随解析器生命周期管理。
 *
 * @see xmarkup_parse
 */
void xmarkup_result_free(XMResult* result);

/**
 * @brief 获取最近一次解析的错误码
 *
 * @param parser 解析器实例
 * @return 错误码，parser 为 NULL 时返回 XM_ERR_NULL_PARSER
 *
 * @see XMError, xmarkup_error_string
 */
XMError xmarkup_last_error(XMParser* parser);

/**
 * @brief 将错误码转换为可读字符串
 *
 * @param error 错误码
 * @return 静态字符串指针（不需要释放）
 *
 * @code
 * printf("error: %s\n", xmarkup_error_string(XM_ERR_NULL_PARSER));
 * // 输出: error: Parser is NULL
 * @endcode
 */
const char* xmarkup_error_string(XMError error);

/**
 * @brief 获取库版本号
 *
 * @return 静态字符串指针，格式为 "MAJOR.MINOR.PATCH"（如 "0.1.0"），不需要释放
 *
 * @code
 * printf("XMarkup version: %s\n", xmarkup_version());
 * @endcode
 */
const char* xmarkup_version(void);

#ifdef __cplusplus
}
#endif

#endif /* XMARKUP_H */
