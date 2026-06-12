import Foundation
import XMarkup

#if os(macOS)
import AppKit

/// macOS 专用：使用 NSTextTable 原生渲染表格（P2 未集成）
///
/// 替换 Core 的纯文本 fallback（A | B），提供带列宽控制、边框和背景的原生表格。
struct XMarkupTableRenderer {

    /// 使用 NSTextTable 渲染表格（macOS 专用）
    /// - Note: 使用 typed theme（theme.table）替代旧的 blockStyles 字典。当前为 sketch 版本，P2 待完善
    static func renderTable(
        _ structure: TableStructure,
        theme: MarkupTheme
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let textTable = NSTextTable()
        // macOS NSTextTable 使用 setColumnCount 而非属性
        textTable.numberOfColumns = max(structure.columnCount, 1)

        let collapsesBorders = theme.table.collapsesBorders
        textTable.collapsesBorders = collapsesBorders

        for (rowIdx, row) in structure.rows.enumerated() {
            for (colIdx, cell) in row.enumerated() {
                let cellBlock = NSTextTableBlock(
                    table: textTable,
                    startingRow: rowIdx,
                    rowSpan: 1,
                    startingColumn: colIdx,
                    columnSpan: 1
                )
                if cell.kind == .tableHeader, let bgColor = theme.table.headerBackgroundColor {
                    cellBlock.backgroundColor = bgColor
                }

                let paraStyle = NSMutableParagraphStyle()
                paraStyle.textBlocks = [cellBlock]

                let cellAttr = NSMutableAttributedString(string: cell.text)
                if cell.text.utf16.count > 0 {
                    cellAttr.addAttribute(.paragraphStyle, value: paraStyle,
                                           range: NSRange(location: 0, length: cell.text.utf16.count))
                }
                // 同行 cell 由 NSTextTableBlock 的 row/column 定位，无需分隔符
                // 只在行首追加换行（第一行除外）
                if colIdx == 0 && rowIdx > 0 {
                    result.append(NSAttributedString(string: "\n"))
                }
                result.append(cellAttr)
            }
        }
        return result
    }
}

#endif
