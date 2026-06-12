import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 表格主题配置
public struct TableTheme: @unchecked Sendable, Equatable {
    /// 表头字体（nil = baseFont.bold + monospaced）
    public var headerFont: XMFont?
    /// 表头背景色
    public var headerBackgroundColor: XMColor?
    /// 正文字体（nil = baseFont monospaced）
    public var bodyFont: XMFont?
    /// 列间距（pt），默认 16pt
    public var columnPadding: CGFloat = 16
    /// 是否合并边框（预留，当前渲染器不实现边框）
    public var collapsesBorders: Bool = true
    /// 边框颜色（预留，当前渲染器不实现边框）
    public var borderColor: XMColor?

    /// 动态 resolve
    public var resolve: (@Sendable (MarkupBlock, RenderingContext, ResolvedTableTheme) -> ResolvedTableTheme?)?

    public init() {}

    public struct ResolvedTableTheme: @unchecked Sendable, Equatable {
        public var headerFont: XMFont?
        public var headerBackgroundColor: XMColor?
        public var bodyFont: XMFont?
        public var columnPadding: CGFloat
        public var collapsesBorders: Bool
        public var borderColor: XMColor?

        public func with<T>(_ keyPath: WritableKeyPath<ResolvedTableTheme, T>, _ value: T) -> ResolvedTableTheme {
            var copy = self
            copy[keyPath: keyPath] = value
            return copy
        }
    }

    public func resolved(for block: MarkupBlock, context: RenderingContext) -> ResolvedTableTheme {
        var result = ResolvedTableTheme(
            headerFont: headerFont,
            headerBackgroundColor: headerBackgroundColor,
            bodyFont: bodyFont,
            columnPadding: columnPadding,
            collapsesBorders: collapsesBorders,
            borderColor: borderColor
        )
        if let resolver = resolve, let override = resolver(block, context, result) {
            result = override
        }
        return result
    }

    public static let `default` = TableTheme()

    public static func == (lhs: TableTheme, rhs: TableTheme) -> Bool {
        lhs.headerFont == rhs.headerFont
            && lhs.headerBackgroundColor == rhs.headerBackgroundColor
            && lhs.bodyFont == rhs.bodyFont
            && lhs.columnPadding == rhs.columnPadding
            && lhs.collapsesBorders == rhs.collapsesBorders
            && lhs.borderColor == rhs.borderColor
    }
}
