import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 链接主题配置
public struct LinkTheme: @unchecked Sendable, Equatable {
    /// 文本颜色
    public var textColor: XMColor?
    /// 下划线样式（nil = 无下划线）
    public var underlineStyle: NSUnderlineStyle?
    /// 下划线颜色（nil = 跟随 textColor）
    public var underlineColor: XMColor?

    /// 动态 resolve
    public var resolve: (@Sendable (MarkupInline, MarkupBlock, RenderingContext, ResolvedLinkTheme) -> ResolvedLinkTheme?)?

    public init() {}

    /// 最终解析结果
    public struct ResolvedLinkTheme: @unchecked Sendable, Equatable {
        public var textColor: XMColor?
        public var underlineStyle: NSUnderlineStyle?
        public var underlineColor: XMColor?

        public func with<T>(_ keyPath: WritableKeyPath<ResolvedLinkTheme, T>, _ value: T) -> ResolvedLinkTheme {
            var copy = self
            copy[keyPath: keyPath] = value
            return copy
        }
    }

    public func resolved(for inline: MarkupInline, block: MarkupBlock, context: RenderingContext) -> ResolvedLinkTheme {
        var result = ResolvedLinkTheme(
            textColor: textColor,
            underlineStyle: underlineStyle,
            underlineColor: underlineColor
        )
        if let resolver = resolve, let override = resolver(inline, block, context, result) {
            result = override
        }
        return result
    }

    public static let `default` = LinkTheme()

    public static func == (lhs: LinkTheme, rhs: LinkTheme) -> Bool {
        lhs.textColor == rhs.textColor
            && lhs.underlineStyle == rhs.underlineStyle
            && lhs.underlineColor == rhs.underlineColor
    }
}
