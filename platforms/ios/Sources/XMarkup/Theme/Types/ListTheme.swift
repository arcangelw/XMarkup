import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 列表主题配置
public struct ListTheme: @unchecked Sendable, Equatable {

    // MARK: - 标记渲染模式

    /// 标记渲染模式
    public enum MarkerMode: String, Sendable, Equatable, CaseIterable {
        /// 自动：文本保持干净，标记由 UI 层（NSLayoutManager / XMarkupTextView）绘制
        case automatic
        /// 手动：标记作为文本前缀插入（"•\t" / "1.\t"），适用于 UILabel 等无 TextKit 场景
        case manual
    }

    /// 标记渲染模式（默认 `.automatic` — NSTextList 原生标记；
    /// XMarkupUI 层通过自定义 NSLayoutManager 修正绘制行为）
    public var markerMode: MarkerMode = .automatic

    // MARK: - 缩进与间距

    /// 每级缩进量（pt）
    public var indentUnit: CGFloat = 24
    /// 有序列表标记类型
    public var orderedMarker: MarkerType = .decimal
    /// 无序列表标记类型
    public var unorderedMarker: MarkerType = .disc
    /// 嵌套有序列表标记类型
    public var nestedOrderedMarker: MarkerType = .decimal
    /// 嵌套无序列表标记类型
    public var nestedUnorderedMarker: MarkerType = .circle
    /// 组内列表项间距（pt）
    public var itemSpacing: CGFloat = 2
    /// 列表组段前间距（nil = fallback 到 paragraph.spacingBefore）
    public var groupSpacingBefore: CGFloat? = nil
    /// 列表组段后间距（nil = fallback 到 paragraph.spacingAfter）
    public var groupSpacingAfter: CGFloat? = nil
    /// 有序列表标记后缀（仅在 `.manual` 模式下生效，默认 "."）
    public var orderedMarkerSuffix: String = "."
    /// 标记与文本之间的额外间距（pt）
    public var markerPadding: CGFloat = 4

    /// 动态 resolve
    public var resolve: (@Sendable (MarkupBlock, RenderingContext, ResolvedListTheme) -> ResolvedListTheme?)?

    public init() {}

    /// 标记类型（与 BlockStyleConfiguration.MarkerType 保持一致）
    public enum MarkerType: String, Sendable, Equatable, CaseIterable {
        case disc, circle, square, decimal
        case lowerAlpha, upperAlpha
        case lowerRoman, upperRoman
        case hyphen, check, box, diamond
    }

    /// 最终解析结果
    public struct ResolvedListTheme: @unchecked Sendable, Equatable {
        public var indentUnit: CGFloat
        public var orderedMarker: MarkerType
        public var unorderedMarker: MarkerType
        public var nestedOrderedMarker: MarkerType
        public var nestedUnorderedMarker: MarkerType
        public var itemSpacing: CGFloat
        public var groupSpacingBefore: CGFloat?
        public var groupSpacingAfter: CGFloat?
        public var orderedMarkerSuffix: String
        public var markerPadding: CGFloat
        public var markerMode: MarkerMode

        public func with<T>(_ keyPath: WritableKeyPath<ResolvedListTheme, T>, _ value: T) -> ResolvedListTheme {
            var copy = self
            copy[keyPath: keyPath] = value
            return copy
        }
    }

    public func resolved(for block: MarkupBlock, context: RenderingContext) -> ResolvedListTheme {
        var result = ResolvedListTheme(
            indentUnit: indentUnit,
            orderedMarker: orderedMarker,
            unorderedMarker: unorderedMarker,
            nestedOrderedMarker: nestedOrderedMarker,
            nestedUnorderedMarker: nestedUnorderedMarker,
            itemSpacing: itemSpacing,
            groupSpacingBefore: groupSpacingBefore,
            groupSpacingAfter: groupSpacingAfter,
            orderedMarkerSuffix: orderedMarkerSuffix,
            markerPadding: markerPadding,
            markerMode: markerMode
        )
        if let resolver = resolve, let override = resolver(block, context, result) {
            result = override
        }
        return result
    }

    /// 将主题 MarkerType 映射为 NSTextList.MarkerFormat
    ///
    /// NSTextList 原生支持的格式有限：
    /// - 数字 → `.decimal`
    /// - 罗马数字 → `.lowercaseRoman` / `.uppercaseRoman`
    /// - 字母序列、check / box / diamond 等不支持的格式回退到 `.disc`
    public static func markerFormat(for type: MarkerType) -> NSTextList.MarkerFormat {
        switch type {
        case .disc:        return .disc
        case .circle:      return .circle
        case .square:      return .square
        case .decimal:     return .decimal
        case .lowerRoman:  return .lowercaseRoman
        case .upperRoman:  return .uppercaseRoman
        case .hyphen:      return .hyphen
        case .lowerAlpha, .upperAlpha, .check, .box, .diamond:
            // NSTextList 不支持字母标记 / check / box / diamond，回退到 disc
            return .disc
        }
    }

    public static let `default` = ListTheme()

    public static func == (lhs: ListTheme, rhs: ListTheme) -> Bool {
        lhs.indentUnit == rhs.indentUnit && lhs.orderedMarker == rhs.orderedMarker
            && lhs.unorderedMarker == rhs.unorderedMarker
            && lhs.nestedOrderedMarker == rhs.nestedOrderedMarker
            && lhs.nestedUnorderedMarker == rhs.nestedUnorderedMarker
            && lhs.itemSpacing == rhs.itemSpacing
            && lhs.groupSpacingBefore == rhs.groupSpacingBefore
            && lhs.groupSpacingAfter == rhs.groupSpacingAfter
            && lhs.orderedMarkerSuffix == rhs.orderedMarkerSuffix
            && lhs.markerPadding == rhs.markerPadding
            && lhs.markerMode == rhs.markerMode
    }
}
