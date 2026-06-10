import Foundation
import XMarkup

#if os(macOS)
import AppKit

/// macOS 专用：将 BlockStyleConfiguration 渲染为 NSTextBlock
///
/// 读取 MarkupTheme.blockStyles，为 blockquote/pre 等元素添加全宽背景色和 per-edge 边框。
/// iOS 不可用（NSTextBlock 不存在于 UIKit）。
struct XMarkupBlockRenderer {

    /// 将 BlockStyleConfiguration 应用为 NSTextBlock（macOS 专用）
    static func applyBlockStyle(
        kind: BlockKind,
        theme: MarkupTheme,
        to paragraphStyle: NSMutableParagraphStyle
    ) {
        guard let key = blockStyleKey(for: kind),
              let config = theme.blockStyles[key] else { return }

        let hasBlockProps = config.backgroundColor != nil || config.borderLeading != nil
        guard hasBlockProps else { return }

        let block = NSTextBlock()
        if let bg = config.backgroundColor, let color = ColorParser.parse(bg) {
            block.backgroundColor = color
        }
        if let border = config.borderLeading, let color = ColorParser.parse(border.color) {
            block.setBorderColor(color, for: .minX)
            block.setWidth(border.width, type: .absoluteValueType, for: .border, edge: .minX)
        }
        paragraphStyle.textBlocks = [block]
    }
}

#endif
