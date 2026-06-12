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
    case media                                               // <img>/<video>/<audio>
    case table(TableStructure)                               // <table>
    case tableRow                                            // <tr>
    case tableCell                                           // <td>
    case tableHeader                                         // <th>
    case definitionTerm                                     // <dt>
    case definitionDescription                              // <dd>
}

/// 表格单元格
///
/// 替代旧的 `MarkupBlock` 作为 cell 容器，语义更精确。
/// 包含文本内容、内联样式以及是否为表头标记。
public struct TableCell: Sendable, Equatable {
    /// 单元格文本内容
    public let text: String
    /// 内联样式（相对于 cell 文本的偏移）
    public let inlines: [MarkupInline]
    /// 是否为表头单元格（`<th>`）
    public let isHeader: Bool

    public init(text: String, inlines: [MarkupInline] = [], isHeader: Bool = false) {
        self.text = text
        self.inlines = inlines
        self.isHeader = isHeader
    }
}

/// 表格结构
///
/// 描述 HTML `<table>` 的行列结构，供渲染器消费。
/// Core 层按行列顺序拼接为等宽文本 + tab stops，
/// XMarkupUI 层可使用 NSTextTable 或自定义视图做高级渲染。
public struct TableStructure: Sendable, Equatable {
    /// 每行每列的单元格
    public let rows: [[TableCell]]
    /// 表头行数
    public let headerRowCount: Int
    /// 列数
    public let columnCount: Int

    public init(rows: [[TableCell]], headerRowCount: Int, columnCount: Int) {
        self.rows = rows
        self.headerRowCount = headerRowCount
        self.columnCount = columnCount
    }
}
