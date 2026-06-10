import Foundation

/// 块级排版配置（值类型，Sendable + Equatable）
/// 渲染器读取此配置构建 NSTextBlock / NSTextTable / NSTextList
public struct BlockStyleConfiguration: Sendable, Equatable {
    // MARK: - NSTextBlock（blockquote, pre, division）
    public var backgroundColor: String?
    public var borderLeading: BorderEdge?
    public var borderTrailing: BorderEdge?
    public var borderTop: BorderEdge?
    public var borderBottom: BorderEdge?
    public var paddingLeading: CGFloat?
    public var paddingTrailing: CGFloat?
    public var paddingTop: CGFloat?
    public var paddingBottom: CGFloat?

    // MARK: - NSTextTable（table）
    public var collapsesBorders: Bool?
    public var layoutAlgorithm: TableLayout?

    // MARK: - NSTextList（listItem）
    public var orderedMarker: MarkerType?
    public var unorderedMarker: MarkerType?
    public var nestedOrderedMarker: MarkerType?
    public var nestedUnorderedMarker: MarkerType?

    public init() {}

    // MARK: - Nested types

    public struct BorderEdge: Sendable, Equatable {
        public var width: CGFloat
        public var color: String // hex: "#RRGGBB"
        public init(width: CGFloat, color: String) {
            self.width = width
            self.color = color
        }
    }

    public enum TableLayout: String, Sendable, Equatable {
        case automatic, fixed
    }

    public enum MarkerType: String, Sendable, Equatable, CaseIterable {
        case disc, circle, square, decimal
        case lowerAlpha, upperAlpha
        case lowerRoman, upperRoman
        case hyphen, check, box, diamond
    }
}
