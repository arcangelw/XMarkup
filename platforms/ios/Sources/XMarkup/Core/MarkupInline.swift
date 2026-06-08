import Foundation

/// 内联样式（字符级）
public struct MarkupInline: Sendable, Equatable {
    /// 在所属 block.text 中的范围（相对于块文本起始位置，UTF-16 码元偏移）
    public let range: NSRange
    /// 内联类型
    public let kind: InlineKind

    public init(range: NSRange, kind: InlineKind) {
        self.range = range
        self.kind = kind
    }
}

/// 内联类型
public enum InlineKind: Sendable, Equatable {
    case bold
    case italic
    case underline
    case strikethrough
    case code
    case mark
    case link(url: String)
    case subscriptText
    case superscript
    case span(styles: [InlineStyle])
}

/// CSS 行内样式
public enum InlineStyle: Sendable, Equatable {
    case foregroundColor(String)    // "#RRGGBB"
    case backgroundColor(String)
    case fontSize(Float)
    case fontWeight(String)
    case fontStyle(String)
    case textDecoration(String)
    case lineHeight(Float)
    case letterSpacing(Float)
}
