import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 预格式化块渲染器 — 处理 pre 的等宽字体和背景色
public struct PreformattedBlockRenderer: BlockRendering, Sendable {
    public init() {}

    public func render(block: MarkupBlock, context: inout RenderingContext) -> NSMutableAttributedString? {
        guard case .preformatted = block.kind else { return nil }

        let theme = context.theme
        let resolved = theme.preformatted.resolved(for: block, context: context)
        let resolvedParagraph = theme.paragraph.resolved(for: block, context: context)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacingBefore = resolvedParagraph.spacingBefore
        paragraphStyle.paragraphSpacing = resolvedParagraph.spacingAfter
        paragraphStyle.lineSpacing = resolvedParagraph.lineSpacing

        let preFont = resolved.font
            ?? XMFont.monospacedSystemFont(ofSize: theme.baseFont.pointSize, weight: .regular)

        var attributes: [NSAttributedString.Key: Any] = [
            .font: preFont,
            .paragraphStyle: paragraphStyle,
        ]
        if let bg = resolved.backgroundColor {
            attributes[.backgroundColor] = bg
        }

        let blockKindName = blockKindName(for: block.kind)
        attributes[.xmarkupTag] = blockKindName
        attributes[.xmarkupBlockKind] = blockKindName

        return NSMutableAttributedString(string: block.text, attributes: attributes)
    }
}
