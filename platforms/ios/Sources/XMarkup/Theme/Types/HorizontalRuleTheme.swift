import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 水平线主题配置
public struct HorizontalRuleTheme: @unchecked Sendable, Equatable {
    /// 最小宽度（pt）
    public var minWidth: CGFloat = 100
    /// 颜色（nil = 使用 separator 系统色）
    public var color: XMColor?
    /// 线条高度（pt）
    public var height: CGFloat = 1

    /// 动态 resolve
    public var resolve: (@Sendable (MarkupBlock, RenderingContext, ResolvedHorizontalRuleTheme) -> ResolvedHorizontalRuleTheme?)?

    public init() {}

    public struct ResolvedHorizontalRuleTheme: @unchecked Sendable, Equatable {
        public var minWidth: CGFloat
        public var color: XMColor?
        public var height: CGFloat

        public func with<T>(_ keyPath: WritableKeyPath<ResolvedHorizontalRuleTheme, T>, _ value: T) -> ResolvedHorizontalRuleTheme {
            var copy = self
            copy[keyPath: keyPath] = value
            return copy
        }
    }

    public func resolved(for block: MarkupBlock, context: RenderingContext) -> ResolvedHorizontalRuleTheme {
        var result = ResolvedHorizontalRuleTheme(minWidth: minWidth, color: color, height: height)
        if let resolver = resolve, let override = resolver(block, context, result) {
            result = override
        }
        return result
    }

    public static let `default` = HorizontalRuleTheme()

    public static func == (lhs: HorizontalRuleTheme, rhs: HorizontalRuleTheme) -> Bool {
        lhs.minWidth == rhs.minWidth && lhs.color == rhs.color && lhs.height == rhs.height
    }
}
