import CXMarkup

/// CSS 行内样式属性类型
public enum XMarkupStyle: Sendable, Equatable {
    case foregroundColor
    case backgroundColor
    case fontSize
    case fontWeight
    case fontStyle
    case textDecoration
    case lineHeight
    case textAlign
    case letterSpacing
    case mediaType
    case mediaQuery
    /// 未知样式，保留原始 C 值
    case unknown(styleValue: UInt32)

    /// 从 C API XMStyleType 值初始化
    init(cValue: XMStyleType) {
        switch cValue {
        case XM_STYLE_FOREGROUND_COLOR: self = .foregroundColor
        case XM_STYLE_BACKGROUND_COLOR: self = .backgroundColor
        case XM_STYLE_FONT_SIZE: self = .fontSize
        case XM_STYLE_FONT_WEIGHT: self = .fontWeight
        case XM_STYLE_FONT_STYLE: self = .fontStyle
        case XM_STYLE_TEXT_DECORATION: self = .textDecoration
        case XM_STYLE_LINE_HEIGHT: self = .lineHeight
        case XM_STYLE_TEXT_ALIGN: self = .textAlign
        case XM_STYLE_LETTER_SPACING: self = .letterSpacing
        case XM_STYLE_MEDIA_TYPE: self = .mediaType
        case XM_STYLE_MEDIA_QUERY: self = .mediaQuery
        default: self = .unknown(styleValue: cValue.rawValue)
        }
    }
}
