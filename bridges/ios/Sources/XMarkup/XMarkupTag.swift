import CXMarkup

/// HTML 标签类型
///
/// 映射 HTML 标签到语义化的 Swift 枚举。
/// 对于未知标签，保留原始 C 值供调试。
public enum XMarkupTag: Sendable, Equatable {
    // 文本样式
    case bold
    case italic
    case underline
    case strikethrough
    case subscriptText
    case superscript
    case mark
    case code
    // 段落结构
    case paragraph
    case heading1
    case heading2
    case heading3
    case heading4
    case heading5
    case heading6
    case blockquote
    case preformatted
    // 链接与媒体
    case link
    case image
    case video
    case videoSource
    case audio
    case audioSource
    // 列表
    case listOrdered
    case listUnordered
    case listItem
    // 表格
    case table
    case tableRow
    case tableCell
    case tableHeader
    // 其他
    case horizontalRule
    case lineBreak
    case division
    case span
    /// 未知标签，保留原始 C 值
    case unknown(tagValue: UInt32)

    /// 从 C API XMTagType 值初始化
    init(cValue: XMTagType) {
        switch cValue {
        case XM_TAG_BOLD:          self = .bold
        case XM_TAG_ITALIC:        self = .italic
        case XM_TAG_UNDERLINE:     self = .underline
        case XM_TAG_STRIKETHROUGH: self = .strikethrough
        case XM_TAG_SUBSCRIPT:     self = .subscriptText
        case XM_TAG_SUPERSCRIPT:   self = .superscript
        case XM_TAG_MARK:          self = .mark
        case XM_TAG_CODE:          self = .code
        case XM_TAG_PARAGRAPH:     self = .paragraph
        case XM_TAG_HEADING_1:     self = .heading1
        case XM_TAG_HEADING_2:     self = .heading2
        case XM_TAG_HEADING_3:     self = .heading3
        case XM_TAG_HEADING_4:     self = .heading4
        case XM_TAG_HEADING_5:     self = .heading5
        case XM_TAG_HEADING_6:     self = .heading6
        case XM_TAG_BLOCKQUOTE:    self = .blockquote
        case XM_TAG_PREFORMATTED:  self = .preformatted
        case XM_TAG_LINK:          self = .link
        case XM_TAG_IMAGE:         self = .image
        case XM_TAG_VIDEO:         self = .video
        case XM_TAG_VIDEO_SOURCE:  self = .videoSource
        case XM_TAG_AUDIO:         self = .audio
        case XM_TAG_AUDIO_SOURCE:  self = .audioSource
        case XM_TAG_LIST_ORDERED:  self = .listOrdered
        case XM_TAG_LIST_UNORDERED: self = .listUnordered
        case XM_TAG_LIST_ITEM:     self = .listItem
        case XM_TAG_TABLE:         self = .table
        case XM_TAG_TABLE_ROW:     self = .tableRow
        case XM_TAG_TABLE_CELL:    self = .tableCell
        case XM_TAG_TABLE_HEADER:  self = .tableHeader
        case XM_TAG_HORIZONTAL_RULE: self = .horizontalRule
        case XM_TAG_LINE_BREAK:    self = .lineBreak
        case XM_TAG_DIVISION:      self = .division
        case XM_TAG_SPAN:          self = .span
        default:                   self = .unknown(tagValue: cValue.rawValue)
        }
    }
}
