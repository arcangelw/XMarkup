import Foundation

#if canImport(UIKit)
import UIKit

/// 将 BlockStyleConfiguration 应用为 NSTextBlock（iOS 路径）
func applyBlockStyle(kind: BlockKind, theme: MarkupTheme, to attributes: inout AttributeContainer) {
    guard let key = blockStyleKey(for: kind),
          let config = theme.blockStyles[key] else { return }

    let hasBlockProps = config.backgroundColor != nil
        || config.borderLeading != nil || config.borderTrailing != nil
        || config.borderTop != nil || config.borderBottom != nil
    guard hasBlockProps else { return }

    let block = NSTextBlock()
    if let bg = config.backgroundColor, let color = ColorParser.parse(bg) {
        block.backgroundColor = color
    }

    // 左边框（blockquote 竖线效果）
    if let border = config.borderLeading, let color = ColorParser.parse(border.color) {
        block.setBorderColor(color, for: .minXEdge)
        block.setWidth(border.width, type: .absolute, for: .minXEdge, rectEdge: .minXEdge)
    }
    if let border = config.borderTrailing, let color = ColorParser.parse(border.color) {
        block.setBorderColor(color, for: .maxXEdge)
        block.setWidth(border.width, type: .absolute, for: .maxXEdge, rectEdge: .maxXEdge)
    }
    if let border = config.borderTop, let color = ColorParser.parse(border.color) {
        block.setBorderColor(color, for: .minYEdge)
        block.setWidth(border.width, type: .absolute, for: .minYEdge, rectEdge: .minYEdge)
    }
    if let border = config.borderBottom, let color = ColorParser.parse(border.color) {
        block.setBorderColor(color, for: .maxYEdge)
        block.setWidth(border.width, type: .absolute, for: .maxYEdge, rectEdge: .maxYEdge)
    }

    attributes[BlockStyleNSTextBlockKey.self] = block
}

#elseif canImport(AppKit)
import AppKit

/// 将 BlockStyleConfiguration 应用为 NSTextBlock（macOS 路径）
func applyBlockStyle(kind: BlockKind, theme: MarkupTheme, to attributes: inout AttributeContainer) {
    guard let key = blockStyleKey(for: kind),
          let config = theme.blockStyles[key] else { return }

    let hasBlockProps = config.backgroundColor != nil
        || config.borderLeading != nil || config.borderTrailing != nil
        || config.borderTop != nil || config.borderBottom != nil
    guard hasBlockProps else { return }

    let block = NSTextBlock()
    if let bg = config.backgroundColor, let color = ColorParser.parse(bg) {
        block.backgroundColor = color
    }

    // macOS 使用 setWidth(_:type:for:edge:) 和 NSRectEdge
    if let border = config.borderLeading, let color = ColorParser.parse(border.color) {
        block.setBorderColor(color, for: .minX)
        block.setWidth(border.width, type: .absoluteValueType, for: .border, edge: .minX)
    }
    if let border = config.borderTrailing, let color = ColorParser.parse(border.color) {
        block.setBorderColor(color, for: .maxX)
        block.setWidth(border.width, type: .absoluteValueType, for: .border, edge: .maxX)
    }
    if let border = config.borderTop, let color = ColorParser.parse(border.color) {
        block.setBorderColor(color, for: .minY)
        block.setWidth(border.width, type: .absoluteValueType, for: .border, edge: .minY)
    }
    if let border = config.borderBottom, let color = ColorParser.parse(border.color) {
        block.setBorderColor(color, for: .maxY)
        block.setWidth(border.width, type: .absoluteValueType, for: .border, edge: .maxY)
    }

    attributes[BlockStyleNSTextBlockKey.self] = block
}
#endif
