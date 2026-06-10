import Foundation

#if canImport(UIKit)
import UIKit

// MARK: - iOS NSTextTable 渲染

func renderTable(_ structure: TableStructure, theme: MarkupTheme) -> NSAttributedString {
    let result = NSMutableAttributedString()
    let textTable = NSTextTable()
    textTable.columnCount = max(structure.columnCount, 1)

    // 从 theme.blockStyles 读取表格样式
    if let tableConfig = theme.blockStyles[.table] {
        textTable.collapsesBorders = tableConfig.collapsesBorders ?? true
    }

    for (rowIdx, row) in structure.rows.enumerated() {
        for (colIdx, cell) in row.enumerated() {
            let cellBlock = NSTextTableBlock(table: textTable,
                                              startingRow: rowIdx,
                                              rowSpan: 1,
                                              startingColumn: colIdx,
                                              columnSpan: 1)

            // 应用 cell 样式
            applyCellBlockStyle(cellBlock, cell: cell, theme: theme)

            let paraStyle = NSMutableParagraphStyle()
            paraStyle.textBlocks = [cellBlock]

            let cellText = cell.text
            let cellAttr = NSMutableAttributedString(string: cellText)

            // 设置 paragraphStyle
            if cellText.utf16.count > 0 {
                cellAttr.addAttribute(.paragraphStyle, value: paraStyle,
                                       range: NSRange(location: 0, length: cellText.utf16.count))
            }

            // 段落间换行（NSTextTable 用 \n 分隔 cell）
            if rowIdx > 0 || colIdx > 0 {
                result.append(NSAttributedString(string: "\n"))
            }
            result.append(cellAttr)
        }
    }

    return result
}

/// 应用 cell 级 NSTextBlock 样式
func applyCellBlockStyle(_ block: NSTextTableBlock, cell: MarkupBlock, theme: MarkupTheme) {
    let cellKey: TagStyleKey = cell.kind == .tableHeader ? .tableHeader : .tableCell
    guard let config = theme.blockStyles[cellKey] else { return }

    if let bg = config.backgroundColor, let color = ColorParser.parse(bg) {
        block.backgroundColor = color
    }
    if let border = config.borderBottom, let color = ColorParser.parse(border.color) {
        block.setBorderColor(color, for: .maxYEdge)
        block.setWidth(border.width, type: .absoluteValueType, for: .border, rectEdge: .maxYEdge)
    }
}

#elseif canImport(AppKit)
import AppKit

/// macOS placeholder — NSTextTable API 与 iOS 不同，暂不实现
func renderTable(_ structure: TableStructure, theme: MarkupTheme) -> NSAttributedString {
    let result = NSMutableAttributedString()
    for (rowIdx, row) in structure.rows.enumerated() {
        if rowIdx > 0 { result.append(NSAttributedString(string: "\n")) }
        let texts = row.map(\.text).joined(separator: " | ")
        result.append(NSAttributedString(string: texts))
    }
    return result
}

func applyCellBlockStyle(_ block: Any, cell: MarkupBlock, theme: MarkupTheme) {
    // macOS stub
}
#endif
