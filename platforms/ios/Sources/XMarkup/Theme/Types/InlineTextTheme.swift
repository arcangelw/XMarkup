import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 内联文本通用主题配置
///
/// 适用于 bold、italic、underline、strikethrough、code、mark、subscript、superscript 等内联样式。
public struct InlineTextTheme: @unchecked Sendable, @unchecked Equatable {
    /// 文本颜色
    public var textColor: XMColor?
    /// 背景色
    public var backgroundColor: XMColor?
    /// 字体（nil = 不覆盖）
    public var font: XMFont?

    /// 动态 resolve
    public var resolve: (@Sendable (MarkupInline, MarkupBlock, RenderingContext, ResolvedInlineTextTheme) -> ResolvedInlineTextTheme?)?

    public init() {}

    /// 最终解析结果
    public struct ResolvedInlineTextTheme: @unchecked Sendable, Equatable {
        public var textColor: XMColor?
        public var backgroundColor: XMColor?
        public var font: XMFont?

        public func with<T>(_ keyPath: WritableKeyPath<ResolvedInlineTextTheme, T>, _ value: T) -> ResolvedInlineTextTheme {
            var copy = self
            copy[keyPath: keyPath] = value
            return copy
        }
    }

    public func resolved(for inline: MarkupInline, block: MarkupBlock, context: RenderingContext) -> ResolvedInlineTextTheme {
        var result = ResolvedInlineTextTheme(
            textColor: textColor,
            backgroundColor: backgroundColor,
            font: font
        )
        if let resolver = resolve, let override = resolver(inline, block, context, result) {
            result = override
        }
        return result
    }

    public static let `default` = InlineTextTheme()

    public static func == (lhs: InlineTextTheme, rhs: InlineTextTheme) -> Bool {
        lhs.textColor == rhs.textColor && lhs.backgroundColor == rhs.backgroundColor && lhs.font == rhs.font
    }
}
