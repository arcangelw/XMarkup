import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 预格式化主题配置
public struct PreformattedTheme: @unchecked Sendable, @unchecked Equatable {
    /// 字体（nil = 自动从 baseFont 派生等宽字体）
    public var font: XMFont?
    /// 背景色
    public var backgroundColor: XMColor?
    /// 内边距（pt）
    public var padding: CGFloat = 8

    /// 动态 resolve
    public var resolve: (@Sendable (MarkupBlock, RenderingContext, ResolvedPreformattedTheme) -> ResolvedPreformattedTheme?)?

    public init() {}

    public struct ResolvedPreformattedTheme: @unchecked Sendable, Equatable {
        public var font: XMFont?
        public var backgroundColor: XMColor?
        public var padding: CGFloat

        public func with<T>(_ keyPath: WritableKeyPath<ResolvedPreformattedTheme, T>, _ value: T) -> ResolvedPreformattedTheme {
            var copy = self
            copy[keyPath: keyPath] = value
            return copy
        }
    }

    public func resolved(for block: MarkupBlock, context: RenderingContext) -> ResolvedPreformattedTheme {
        var result = ResolvedPreformattedTheme(
            font: font,
            backgroundColor: backgroundColor,
            padding: padding
        )
        if let resolver = resolve, let override = resolver(block, context, result) {
            result = override
        }
        return result
    }

    public static let `default` = PreformattedTheme()

    public static func == (lhs: PreformattedTheme, rhs: PreformattedTheme) -> Bool {
        lhs.font == rhs.font && lhs.backgroundColor == rhs.backgroundColor && lhs.padding == rhs.padding
    }
}
