import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 默认表格渲染器 — 将表格渲染为 tab 分隔的等宽文本 + 元数据标注
///
/// 使用等宽字体 + 自定义 tab stops 实现列对齐，对齐 Web 浏览器展示效果。
/// 不添加视觉装饰字符（`|`、`─` 等），保留原始数据。
/// XMarkupUI 层读取元数据负责高级视觉渲染（边框、列宽控制）。
public struct DefaultTableRenderer: BlockRendering, Sendable {
    public init() {}

    public func render(block: MarkupBlock, context: RenderingContext) -> NSMutableAttributedString? {
        guard case .table(let structure) = block.kind else { return nil }
        return renderTable(structure, theme: context.theme)
    }

    // MARK: - Table Rendering

    private func renderTable(_ structure: TableStructure, theme: MarkupTheme) -> NSMutableAttributedString {
        let result = NSMutableAttributedString()
        guard !structure.rows.isEmpty else { return result }

        let columnCount = max(structure.columnCount, 1)
        let columnPadding: CGFloat = 8

        // 第一遍：计算每列最大宽度（字符数）
        var maxWidths = [Int](repeating: 0, count: columnCount)
        for row in structure.rows {
            for (colIdx, cell) in row.enumerated() where colIdx < columnCount {
                maxWidths[colIdx] = max(maxWidths[colIdx], cell.text.utf16.count)
            }
        }

        // 计算 tab stop 位置（用等宽字体估算宽度）
        // 等宽字体中每个字符宽度 ≈ baseFont 的 '0' 宽度
        let monoFont = theme.preformatted.font
            ?? XMFont.monospacedSystemFont(ofSize: theme.baseFont.pointSize, weight: .regular)
        let charWidth = monoFont.pointSize * 0.6  // 等宽字体字符宽 ≈ 字号 × 0.6
        var tabLocations: [CGFloat] = []
        for colIdx in 0..<columnCount {
            let prevTab = tabLocations.last ?? 0
            let cellWidth = CGFloat(maxWidths[colIdx]) * charWidth + columnPadding
            tabLocations.append(prevTab + cellWidth)
        }

        // 第二遍：构建行，设置 tab stops 和等宽字体
        for (rowIdx, row) in structure.rows.enumerated() {
            if rowIdx > 0 { result.append(NSAttributedString(string: "\n")) }

            let line = row.map(\.text).joined(separator: "\t")
            let isHeader = rowIdx < structure.headerRowCount

            let paraStyle = NSMutableParagraphStyle()
            paraStyle.tabStops = tabLocations.map { NSTextTab(textAlignment: .left, location: $0) }
            // 确保最后一个 tab 之后的文本也左对齐
            if let last = tabLocations.last {
                paraStyle.defaultTabInterval = last + columnPadding
            }

            let textFont: XMFont
            if isHeader, let headerFont = theme.table.headerFont {
                textFont = deriveFont(from: headerFont, addTraits: traitBold)
            } else if isHeader {
                textFont = deriveFont(from: monoFont, addTraits: traitBold)
            } else {
                textFont = monoFont
            }

            let attrs: [NSAttributedString.Key: Any] = [
                .font: textFont,
                .paragraphStyle: paraStyle,
                .xmarkupBlockKind: "tableRow",
                .xmarkupTag: "tableRow",
                .xmarkupTableColumnCount: columnCount,
                .xmarkupTableHeaderRowCount: structure.headerRowCount,
                .xmarkupTableRowIndex: rowIdx,
            ]

            result.append(NSAttributedString(string: line, attributes: attrs))
        }
        return result
    }
}
