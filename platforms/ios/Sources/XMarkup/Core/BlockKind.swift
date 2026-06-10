import Foundation

/// 标题级别
///
/// 对应 HTML 的 `<h1>` ~ `<h6>` 标签，rawValue 即标题级别数字。
public enum Level: Int, Sendable, Equatable, Comparable, Codable {
    case h1 = 1  // <h1>，最大标题
    case h2 = 2  // <h2>
    case h3 = 3  // <h3>
    case h4 = 4  // <h4>
    case h5 = 5  // <h5>
    case h6 = 6  // <h6>，最小标题

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
    case tableRow                                            // <tr>
    case tableCell                                           // <td>
    case tableHeader                                         // <th>
}

/// 表格结构
///
/// P3 远期规划，当前按行列顺序拼接为纯文本段落，无特殊布局。
public struct TableStructure: Sendable, Equatable {
    /// 每行每列的块
    public let rows: [[MarkupBlock]]
    /// 表头行数
    public let headerRowCount: Int
    /// 列数
    public let columnCount: Int

    public init(rows: [[MarkupBlock]], headerRowCount: Int, columnCount: Int) {
        self.rows = rows
        self.headerRowCount = headerRowCount
        self.columnCount = columnCount
    }
}
