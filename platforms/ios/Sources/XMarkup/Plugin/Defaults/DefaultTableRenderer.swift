import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 默认表格渲染器 — 将表格渲染为 tab 分隔的纯文本 + 元数据标注
///
/// 不添加视觉装饰字符（`|`、`─` 等），保留原始数据。
/// XMarkupUI 层读取元数据负责视觉渲染（边框、列宽对齐）。
public struct DefaultTableRenderer: BlockRendering, Sendable {
    public init() {}

    public func render(block: MarkupBlock, context: RenderingContext) -> AttributedString? {
        guard case .table(let structure) = block.kind else { return nil }
        return renderTable(structure, theme: context.theme)
    }

    // MARK: - Table Rendering

    private func renderTable(_ structure: TableStructure, theme: MarkupTheme) -> AttributedString {
        let result = NSMutableAttributedString()
        guard !structure.rows.isEmpty else { return AttributedString(result) }

        let blockKindKey = NSAttributedString.Key(XMarkupBlockKindKey.name)
        let tagKey = NSAttributedString.Key(XMarkupTagKey.name)
        let tableColumnCountKey = NSAttributedString.Key("XMarkup.TableColumnCount")
        let tableHeaderCountKey = NSAttributedString.Key("XMarkup.TableHeaderRowCount")
        let tableRowIndexKey = NSAttributedString.Key("XMarkup.TableRowIndex")

        for (rowIdx, row) in structure.rows.enumerated() {
            if rowIdx > 0 { result.append(NSAttributedString(string: "\n")) }

            let line = row.map(\.text).joined(separator: "\t")
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
        return AttributedString(result)
    }
}
