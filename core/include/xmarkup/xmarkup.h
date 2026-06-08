#ifndef XMARKUP_H
#define XMARKUP_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* 样式枚举 */
typedef enum XMTagType {
    XM_TAG_UNKNOWN       = 0,
    /* 文本样式 */
    XM_TAG_BOLD          = 1,
    XM_TAG_ITALIC        = 2,
    XM_TAG_UNDERLINE     = 3,
    XM_TAG_STRIKETHROUGH = 4,
    XM_TAG_SUBSCRIPT     = 5,
    XM_TAG_SUPERSCRIPT   = 6,
    XM_TAG_MARK          = 7,
    XM_TAG_CODE          = 8,
    /* 段落结构 */
    XM_TAG_PARAGRAPH     = 20,
    XM_TAG_HEADING_1     = 21,
    XM_TAG_HEADING_2     = 22,
    XM_TAG_HEADING_3     = 23,
    XM_TAG_HEADING_4     = 24,
    XM_TAG_HEADING_5     = 25,
    XM_TAG_HEADING_6     = 26,
    XM_TAG_BLOCKQUOTE    = 27,
    XM_TAG_PREFORMATTED  = 28,
    /* 链接与媒体 */
    XM_TAG_LINK          = 40,
    XM_TAG_IMAGE         = 41,
    XM_TAG_VIDEO         = 42,
    XM_TAG_VIDEO_SOURCE  = 43,
    XM_TAG_AUDIO         = 44,
    XM_TAG_AUDIO_SOURCE  = 45,
    /* 列表 */
    XM_TAG_LIST_ORDERED   = 50,
    XM_TAG_LIST_UNORDERED = 51,
    XM_TAG_LIST_ITEM      = 52,
    /* 表格 */
    XM_TAG_TABLE         = 60,
    XM_TAG_TABLE_ROW     = 61,
    XM_TAG_TABLE_CELL    = 62,
    XM_TAG_TABLE_HEADER  = 63,
    /* 其他 */
    XM_TAG_HORIZONTAL_RULE = 70,
    XM_TAG_LINE_BREAK    = 71,
    XM_TAG_DIVISION      = 72,
    XM_TAG_SPAN          = 73,
} XMTagType;

/* CSS 样式属性 */
typedef enum XMStyleType {
    XM_STYLE_FOREGROUND_COLOR = 1,
    XM_STYLE_BACKGROUND_COLOR = 2,
    XM_STYLE_FONT_SIZE        = 3,
    XM_STYLE_FONT_WEIGHT      = 4,
    XM_STYLE_FONT_STYLE       = 5,
    XM_STYLE_TEXT_DECORATION   = 6,
    XM_STYLE_LINE_HEIGHT      = 7,
    XM_STYLE_TEXT_ALIGN       = 8,
    XM_STYLE_LETTER_SPACING   = 9,
    XM_STYLE_MEDIA_TYPE       = 10,
    XM_STYLE_MEDIA_QUERY      = 11,
} XMStyleType;

/* 错误码 */
typedef enum XMError {
    XM_OK                   = 0,
    XM_ERR_NULL_PARSER      = -1,
    XM_ERR_NULL_INPUT       = -2,
    XM_ERR_NESTING_OVERFLOW = -3,
    XM_ERR_ALLOC_FAILED     = -4,
} XMError;

/* 文本区间（UTF-16 索引） */
typedef struct XMRange {
    uint32_t start;
    uint32_t end;
} XMRange;

/* 样式单元 */
typedef struct XMSpan {
    XMRange     range;
    XMTagType   tag;
    XMStyleType style;
    const char* value;
    uint32_t    value_len;
} XMSpan;

/* 解析结果 */
typedef struct XMResult {
    XMError       error;
    const char*   text;
    uint32_t      text_len;
    const XMSpan* spans;
    uint32_t      span_count;
} XMResult;

/* 配置 */
typedef struct XMConfig {
    uint8_t  enable_autocorrect;
    uint16_t max_nesting_depth;
    float    base_font_size;       /* 基准字号（px），支持浮点精度 */
} XMConfig;

/* 不透明解析器句柄 */
typedef struct XMParser XMParser;

/* 生命周期 */
XMParser* xmarkup_create(const XMConfig* config);
void      xmarkup_destroy(XMParser* parser);

/* 核心解析 */
XMResult* xmarkup_parse(XMParser* parser, const char* html, size_t length);
void      xmarkup_result_free(XMResult* result);

/* 错误查询 */
XMError     xmarkup_last_error(XMParser* parser);
const char* xmarkup_error_string(XMError error);

/* 版本查询 */
const char* xmarkup_version(void);

#ifdef __cplusplus
}
#endif

#endif /* XMARKUP_H */
