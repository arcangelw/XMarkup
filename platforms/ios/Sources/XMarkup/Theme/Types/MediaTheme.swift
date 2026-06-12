import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 媒体主题配置
///
/// 控制 `<img>` / `<video>` / `<audio>` 占位图的视觉样式。
/// 真实图片加载策略由 `MediaRenderingStrategy` 控制。
public struct MediaTheme: @unchecked Sendable, Equatable {
    /// 占位图背景色（nil = 使用系统浅灰）
    public var placeholderBackgroundColor: XMColor?
    /// 占位图 SF Symbol 图标色（nil = 使用系统灰）
    public var placeholderTintColor: XMColor?
    /// 默认占位尺寸（当 suggestedSize 无效时使用）
    public var defaultSize: CGSize = CGSize(width: 200, height: 150)

    /// 动态 resolve
    public var resolve: (@Sendable (MarkupBlock, RenderingContext, ResolvedMediaTheme) -> ResolvedMediaTheme?)?

    public init() {}

    public struct ResolvedMediaTheme: @unchecked Sendable, Equatable {
        public var placeholderBackgroundColor: XMColor?
        public var placeholderTintColor: XMColor?
        public var defaultSize: CGSize

        public func with<T>(_ keyPath: WritableKeyPath<ResolvedMediaTheme, T>, _ value: T) -> ResolvedMediaTheme {
            var copy = self
            copy[keyPath: keyPath] = value
            return copy
        }
    }

    public func resolved(for block: MarkupBlock, context: RenderingContext) -> ResolvedMediaTheme {
        var result = ResolvedMediaTheme(
            placeholderBackgroundColor: placeholderBackgroundColor,
            placeholderTintColor: placeholderTintColor,
            defaultSize: defaultSize
        )
        if let resolver = resolve, let override = resolver(block, context, result) {
            result = override
        }
        return result
    }

    public static let `default` = MediaTheme()

    public static func == (lhs: MediaTheme, rhs: MediaTheme) -> Bool {
        lhs.placeholderBackgroundColor == rhs.placeholderBackgroundColor
            && lhs.placeholderTintColor == rhs.placeholderTintColor
            && lhs.defaultSize == rhs.defaultSize
    }
}
