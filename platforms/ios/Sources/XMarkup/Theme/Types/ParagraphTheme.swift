import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 段落主题配置
///
/// 控制所有段落的默认间距、文本颜色和对齐方式。
/// 作为其他块级主题的 spacing fallback。
public struct ParagraphTheme: Sendable, Equatable {
    /// 段前间距（pt）
    public var spacingBefore: CGFloat = 8
    /// 段后间距（pt）
    public var spacingAfter: CGFloat = 8
    /// 行间距（pt）
    public var lineSpacing: CGFloat = 0
    /// 文本颜色（nil = 跟随系统默认）
    public var textColor: XMColor?
    /// 文本对齐（nil = 跟随系统默认 .natural）
    public var alignment: NSTextAlignment?

    public init(
        spacingBefore: CGFloat = 8,
        spacingAfter: CGFloat = 8,
        lineSpacing: CGFloat = 0,
        textColor: XMColor? = nil,
        alignment: NSTextAlignment? = nil
    ) {
        self.spacingBefore = spacingBefore
        self.spacingAfter = spacingAfter
        self.lineSpacing = lineSpacing
        self.textColor = textColor
        self.alignment = alignment
    }

    public static let `default` = ParagraphTheme()
}
