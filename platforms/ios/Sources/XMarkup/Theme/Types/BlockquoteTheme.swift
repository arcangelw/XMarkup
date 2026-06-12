import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 引用块主题配置
public struct BlockquoteTheme: @unchecked Sendable, Equatable {
    /// 文本缩进量（pt），默认 20pt 对齐 Web `margin: 1em 40px` 的视觉效果
    public var indent: CGFloat = 20
    /// 文本颜色
    public var textColor: XMColor?
    /// 左侧边框宽度（pt）
    public var borderWidth: CGFloat = 3
    /// 左侧边框颜色（nil = 使用系统灰色）
    public var borderColor: XMColor?
    /// 边框相对缩进后文本起点的水平偏移
    public var borderOffset: CGFloat = -6
    /// 背景色
    public var backgroundColor: XMColor?
    /// 内边距（pt）
    public var padding: CGFloat = 8

    /// 动态 resolve
    public var resolve: (@Sendable (MarkupBlock, RenderingContext, ResolvedBlockquoteTheme) -> ResolvedBlockquoteTheme?)?

    public init() {
        #if canImport(UIKit)
        self.textColor = .secondaryLabel
        #elseif canImport(AppKit)
        self.textColor = .secondaryLabelColor
        #endif
    }

    /// 最终解析结果
    public struct ResolvedBlockquoteTheme: @unchecked Sendable, Equatable {
        public var indent: CGFloat
        public var textColor: XMColor?
        public var borderWidth: CGFloat
        public var borderColor: XMColor?
        public var borderOffset: CGFloat
        public var backgroundColor: XMColor?
        public var padding: CGFloat

        public func with<T>(_ keyPath: WritableKeyPath<ResolvedBlockquoteTheme, T>, _ value: T) -> ResolvedBlockquoteTheme {
            var copy = self
            copy[keyPath: keyPath] = value
            return copy
        }
    }

    /// 解析为最终渲染配置
    public func resolved(for block: MarkupBlock, context: RenderingContext) -> ResolvedBlockquoteTheme {
        var result = ResolvedBlockquoteTheme(
            indent: indent,
            textColor: textColor,
            borderWidth: borderWidth,
            borderColor: borderColor,
            borderOffset: borderOffset,
            backgroundColor: backgroundColor,
            padding: padding
        )
        if let resolver = resolve, let override = resolver(block, context, result) {
            result = override
        }
        return result
    }

    public static let `default` = BlockquoteTheme()

    public static func == (lhs: BlockquoteTheme, rhs: BlockquoteTheme) -> Bool {
        lhs.indent == rhs.indent && lhs.textColor == rhs.textColor
            && lhs.borderWidth == rhs.borderWidth && lhs.borderColor == rhs.borderColor
            && lhs.borderOffset == rhs.borderOffset
            && lhs.backgroundColor == rhs.backgroundColor && lhs.padding == rhs.padding
    }
}
