import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 引用块渲染器 — 处理 blockquote 的缩进、文字色、背景色
///
/// 左侧竖线由 UI 层 BlockquoteLayoutManager（iOS）或
/// PlatformEnhancementPlugin（macOS）绘制。
public struct BlockquoteBlockRenderer: BlockRendering, Sendable {
    public init() {}

    public func render(block: MarkupBlock, context: inout RenderingContext) -> NSMutableAttributedString? {
        guard case .blockquote = block.kind else { return nil }

        let theme = context.theme
        let resolved = theme.blockquote.resolved(for: block, context: context)
        let resolvedParagraph = theme.paragraph.resolved(for: block, context: context)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacingBefore = resolvedParagraph.spacingBefore
        paragraphStyle.paragraphSpacing = resolvedParagraph.spacingAfter
        paragraphStyle.lineSpacing = resolvedParagraph.lineSpacing
        paragraphStyle.headIndent = resolved.indent
        paragraphStyle.firstLineHeadIndent = resolved.indent

        var attributes: [NSAttributedString.Key: Any] = [
            .font: theme.baseFont,
            .paragraphStyle: paragraphStyle,
        ]
        if let textColor = resolved.textColor {
            attributes[.foregroundColor] = textColor
        }
        if let bg = resolved.backgroundColor {
            attributes[.backgroundColor] = bg
        }

        let blockKindName = blockKindName(for: block.kind)
        attributes[.xmarkupTag] = blockKindName
        attributes[.xmarkupBlockKind] = blockKindName

        return NSMutableAttributedString(string: block.text, attributes: attributes)
    }
}
