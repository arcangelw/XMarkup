import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 默认块级渲染器 — 处理段落和兜底块类型
///
/// 只处理 `.paragraph`、`.division` 和无匹配类型的兜底。
/// 其他块类型（heading/blockquote/listItem/preformatted/hr）由专门的子渲染器处理。
///
/// 职责：
/// - 段落主题消费（spacing、alignment、textColor）
/// - 块级自定义 key 属性（xmarkupTag、xmarkupBlockKind）
public struct DefaultBlockRenderer: BlockRendering, Sendable {
    public init() {}

    public func render(block: MarkupBlock, context: inout RenderingContext) -> NSMutableAttributedString? {
        // 这些类型由专门的子渲染器处理
        if case .table = block.kind { return nil }
        if block.attachment != nil { return nil }
        switch block.kind {
        case .heading, .blockquote, .listItem, .preformatted, .horizontalRule,
             .definitionTerm, .definitionDescription:
            return nil
        default:
            break
        }

        let theme = context.theme
        let resolvedParagraph = theme.paragraph.resolved(for: block, context: context)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacingBefore = resolvedParagraph.spacingBefore
        paragraphStyle.paragraphSpacing = resolvedParagraph.spacingAfter
        paragraphStyle.lineSpacing = resolvedParagraph.lineSpacing
        if let alignment = resolvedParagraph.alignment {
            paragraphStyle.alignment = alignment
        }

        var attributes: [NSAttributedString.Key: Any] = [
            .font: theme.baseFont,
            .paragraphStyle: paragraphStyle,
        ]

        if let textColor = resolvedParagraph.textColor {
            attributes[.foregroundColor] = textColor
        }

        // 自定义 key
        let blockKindName = blockKindName(for: block.kind)
        attributes[.xmarkupTag] = blockKindName
        attributes[.xmarkupBlockKind] = blockKindName

        return NSMutableAttributedString(string: block.text, attributes: attributes)
    }
}
