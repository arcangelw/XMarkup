import Foundation

/// 列表主题配置
public struct ListTheme: @unchecked Sendable, Equatable {
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
            groupSpacingAfter: groupSpacingAfter
        )
        if let resolver = resolve, let override = resolver(block, context, result) {
            result = override
        }
        return result
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
    }
}
