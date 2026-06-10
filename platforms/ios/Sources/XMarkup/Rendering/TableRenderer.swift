import Foundation

// MARK: - 表格渲染（跨平台通用）

/// 渲染表格为纯文本近似。
///
/// iOS 无 NSTextTable 支持，使用 `|` 分隔的纯文本近似。
/// macOS 可在 XMarkupUI 层使用 NSTextTable 增强原生渲染。
/// 语义信息通过 XMarkupScope key 标注，供 UI 层读取。
///
/// - Parameters:
///   - structure: 表格结构（由 MarkupDocumentBuilder.buildTableStructure() 构建）
///   - theme: 当前主题配置
/// - Returns: 纯文本近似的 NSAttributedString
func renderTable(_ structure: TableStructure, theme: MarkupTheme) -> NSAttributedString {
    let result = NSMutableAttributedString()
    for (rowIdx, row) in structure.rows.enumerated() {
        if rowIdx > 0 { result.append(NSAttributedString(string: "\n")) }
        let texts = row.map(\.text).joined(separator: " | ")
        result.append(NSAttributedString(string: texts))
    }
    return result
}
