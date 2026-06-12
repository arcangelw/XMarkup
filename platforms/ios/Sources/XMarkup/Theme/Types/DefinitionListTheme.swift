import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 定义列表主题配置
///
/// 控制 `<dl><dt><dd>` 的渲染样式。
/// - `<dt>` 术语：可配置字体（默认 nil → 正文 bold）
/// - `<dd>` 描述：左侧缩进 + 可选颜色
public struct DefinitionListTheme: @unchecked Sendable, Equatable {
    /// 术语字体（nil = 继承正文字体 + bold trait）
    public var termFont: XMFont?
    /// 术语文字颜色（nil = 继承正文颜色）
    public var termTextColor: XMColor?
    /// 描述左侧缩进（pt），默认 24pt
    public var descriptionIndent: CGFloat = 24
    /// 描述文字颜色（nil = 继承正文颜色）
    public var descriptionColor: XMColor?
    /// dt-dd 对之间的额外间距（pt），默认 4pt
    public var pairSpacing: CGFloat = 4

    /// 动态 resolve
    public var resolve: (@Sendable (MarkupBlock, RenderingContext, ResolvedDefinitionListTheme) -> ResolvedDefinitionListTheme?)?

    public init() {}

    public struct ResolvedDefinitionListTheme: @unchecked Sendable, Equatable {
        public var termFont: XMFont?
        public var termTextColor: XMColor?
        public var descriptionIndent: CGFloat
        public var descriptionColor: XMColor?
        public var pairSpacing: CGFloat

        public func with<T>(_ keyPath: WritableKeyPath<ResolvedDefinitionListTheme, T>, _ value: T) -> ResolvedDefinitionListTheme {
            var copy = self
            copy[keyPath: keyPath] = value
            return copy
        }
    }

    public func resolved(for block: MarkupBlock, context: RenderingContext) -> ResolvedDefinitionListTheme {
        var result = ResolvedDefinitionListTheme(
            termFont: termFont,
            termTextColor: termTextColor,
            descriptionIndent: descriptionIndent,
            descriptionColor: descriptionColor,
            pairSpacing: pairSpacing
        )
        if let resolver = resolve, let override = resolver(block, context, result) {
            result = override
        }
        return result
    }

    public static let `default` = DefinitionListTheme()

    public static func == (lhs: DefinitionListTheme, rhs: DefinitionListTheme) -> Bool {
        lhs.termFont == rhs.termFont
            && lhs.termTextColor == rhs.termTextColor
            && lhs.descriptionIndent == rhs.descriptionIndent
            && lhs.descriptionColor == rhs.descriptionColor
            && lhs.pairSpacing == rhs.pairSpacing
    }
}
