import Foundation

/// 段落排版配置
///
/// 控制 block 之间的纵向间距和 block 内部的行间距。
/// 通过 `NSParagraphStyle` 应用于 `AttributedString` 的每个 block。
///
/// 使用方式：
/// ```swift
/// let theme = MarkupTheme {
///     ParagraphSpacing(spacingBefore: 12, spacingAfter: 12, lineSpacing: 4)
/// }
/// ```
public struct ParagraphSpacing: Sendable, Equatable {
    /// 段前间距（pt），作用于当前 block 上方的空白距离
    public var spacingBefore: CGFloat
    /// 段后间距（pt），作用于当前 block 下方的空白距离
    public var spacingAfter: CGFloat
    /// 行间距（pt），作用于当前 block 内各行之间的额外距离，默认 0
    public var lineSpacing: CGFloat

    public init(
        spacingBefore: CGFloat = 8,
        spacingAfter: CGFloat = 8,
        lineSpacing: CGFloat = 0
    ) {
        self.spacingBefore = spacingBefore
        self.spacingAfter = spacingAfter
        self.lineSpacing = lineSpacing
    }

    /// 默认段落间距：段前 8pt、段后 8pt、行间距 0
    public static let `default` = ParagraphSpacing()
}
