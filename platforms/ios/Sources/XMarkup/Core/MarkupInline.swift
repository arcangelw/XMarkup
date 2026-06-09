import Foundation

/// 内联样式（字符级）
///
/// `range` 是相对于所属 `MarkupBlock.text` 的 UTF-16 NSRange 偏移。
///
/// ```swift
/// let inline = doc.blocks[0].inlines[0]
/// // inline.range = NSRange(location: 6, length: 4)
/// // inline.kind = .bold
/// ```
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
    case bold              // <b> 或 <strong>
    case italic            // <i> 或 <em>
    case underline         // <u>
    case strikethrough     // <s>、<strike> 或 <del>
    case code              // <code>
    case mark              // <mark>
    case link(url: String) // <a href="...">
    case subscriptText     // <sub>
    case superscript       // <sup>
    case span(styles: [InlineStyle]) // <span style="...">
}

/// CSS 行内样式
public enum InlineStyle: Sendable, Equatable {
    case foregroundColor(String)    // color:#RRGGBB
    case backgroundColor(String)    // background-color:#RRGGBB
    case fontSize(Float)            // font-size（已换算为 px）
    case fontWeight(String)         // font-weight（normal/bold/100-900）
    case fontStyle(String)          // font-style（italic/normal）
    case textDecoration(String)     // text-decoration（underline/line-through）
    case lineHeight(Float)          // line-height（P2 保留）
    case letterSpacing(Float)       // letter-spacing（P2 保留）
    case textAlign(String)          // text-align（center/left/right/justify）
}
