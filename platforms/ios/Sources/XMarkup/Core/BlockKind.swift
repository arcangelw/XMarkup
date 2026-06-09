import Foundation

/// 标题级别
public enum Level: Int, Sendable, Equatable, Comparable, Codable {
    case h1 = 1, h2, h3, h4, h5, h6

    public static func < (lhs: Level, rhs: Level) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// 段落类型
public enum BlockKind: Sendable, Equatable {
    case paragraph                                           // <p>
    case heading(Level)                                      // <h1>~<h6>
    case blockquote                                          // <blockquote>
    case preformatted                                        // <pre>
    case listItem(isOrdered: Bool, indentLevel: Int)         // <li>
    case division                                            // <div>
    case horizontalRule                                      // <hr>
    case table(TableStructure)                               // <table>
}

/// 表格结构
public struct TableStructure: Sendable, Equatable {
    public let rows: [[MarkupBlock]]
    public let headerRowCount: Int
    public let columnCount: Int

    public init(rows: [[MarkupBlock]], headerRowCount: Int, columnCount: Int) {
        self.rows = rows
        self.headerRowCount = headerRowCount
        self.columnCount = columnCount
    }
}
