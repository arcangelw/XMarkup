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
public struct ParagraphTheme: @unchecked Sendable, Equatable {
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

    /// 动态 resolve
    public var resolve: (@Sendable (MarkupBlock, RenderingContext, ResolvedParagraphTheme) -> ResolvedParagraphTheme?)?

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

    /// 最终解析结果
    public struct ResolvedParagraphTheme: @unchecked Sendable, Equatable {
        public var spacingBefore: CGFloat
        public var spacingAfter: CGFloat
        public var lineSpacing: CGFloat
        public var textColor: XMColor?
        public var alignment: NSTextAlignment?

        public func with<T>(_ keyPath: WritableKeyPath<ResolvedParagraphTheme, T>, _ value: T) -> ResolvedParagraphTheme {
            var copy = self
            copy[keyPath: keyPath] = value
            return copy
        }
    }

    /// 解析为最终渲染配置
    public func resolved(for block: MarkupBlock, context: RenderingContext) -> ResolvedParagraphTheme {
        var result = ResolvedParagraphTheme(
            spacingBefore: spacingBefore,
            spacingAfter: spacingAfter,
            lineSpacing: lineSpacing,
            textColor: textColor,
            alignment: alignment
        )
        if let resolver = resolve, let override = resolver(block, context, result) {
            result = override
        }
        return result
    }

    public static let `default` = ParagraphTheme()

    // Equatable 排除 resolve（闭包不可比较）
    public static func == (lhs: ParagraphTheme, rhs: ParagraphTheme) -> Bool {
        lhs.spacingBefore == rhs.spacingBefore
            && lhs.spacingAfter == rhs.spacingAfter
            && lhs.lineSpacing == rhs.lineSpacing
            && lhs.textColor == rhs.textColor
            && lhs.alignment == rhs.alignment
    }
}
