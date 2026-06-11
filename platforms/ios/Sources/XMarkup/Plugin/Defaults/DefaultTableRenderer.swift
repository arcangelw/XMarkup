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
        let nsAttr = renderTable(structure, theme: context.theme)
        return AttributedString(nsAttr)
    }
}
