import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - 表格渲染（数据层：tab 分隔 + 元数据标注）

/// 渲染表格为 tab 分隔的纯文本 + 元数据标注。
///
/// 不添加任何视觉装饰字符（`|`、`─` 等），保留原始数据。
/// XMarkupUI 层读取元数据负责视觉渲染（边框、列宽对齐）。
///
/// - Parameters:
///   - structure: 表格结构（由 MarkupDocumentBuilder.buildTableStructure() 构建）
///   - theme: 当前主题配置
/// - Returns: tab 分隔的 NSAttributedString，携带表格元数据
func renderTable(_ structure: TableStructure, theme: MarkupTheme) -> NSAttributedString {
    let result = NSMutableAttributedString()
    guard !structure.rows.isEmpty else { return result }

    let blockKindKey = NSAttributedString.Key(XMarkupBlockKindKey.name)
    let tagKey = NSAttributedString.Key(XMarkupTagKey.name)
    let tableColumnCountKey = NSAttributedString.Key("XMarkup.TableColumnCount")
    let tableHeaderCountKey = NSAttributedString.Key("XMarkup.TableHeaderRowCount")
    let tableRowIndexKey = NSAttributedString.Key("XMarkup.TableRowIndex")

    for (rowIdx, row) in structure.rows.enumerated() {
        if rowIdx > 0 { result.append(NSAttributedString(string: "\n")) }

        // 每行一个段落，cell 间用 tab 分隔
        let line = row.map(\.text).joined(separator: "\t")

        // 表头行使用粗体
        let isHeader = rowIdx < structure.headerRowCount
        var attrs: [NSAttributedString.Key: Any] = [
            blockKindKey: "tableRow",
            tagKey: "tableRow",
            tableColumnCountKey: structure.columnCount,
            tableHeaderCountKey: structure.headerRowCount,
            tableRowIndexKey: rowIdx,
        ]
        if isHeader {
            #if canImport(UIKit)
            attrs[.font] = UIFont.boldSystemFont(ofSize: theme.baseFont.pointSize)
            #elseif canImport(AppKit)
            attrs[.font] = NSFont.boldSystemFont(ofSize: theme.baseFont.pointSize)
            #endif
        }

        result.append(NSAttributedString(string: line, attributes: attrs))
    }
    return result
}
