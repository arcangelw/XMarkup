import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 定义列表渲染器 — 处理 `<dt>` 和 `<dd>`
///
/// - `<dt>` 术语：应用 theme.definitionList 的 termFont（默认 bold）
/// - `<dd>` 描述：应用 theme.definitionList 的 indent + 可选颜色
public struct DefinitionListBlockRenderer: BlockRendering, Sendable {
    public init() {}

    public func render(block: MarkupBlock, context: inout RenderingContext) -> NSMutableAttributedString? {
        let theme = context.theme
        let resolved = theme.definitionList.resolved(for: block, context: context)

        let paragraphStyle = NSMutableParagraphStyle()

        switch block.kind {
        case .definitionTerm:
            // 段落间距（pairSpacing 用于 dt-dd 对之间）
            let resolvedParagraph = theme.paragraph.resolved(for: block, context: context)
            paragraphStyle.paragraphSpacingBefore = resolvedParagraph.spacingBefore
            paragraphStyle.paragraphSpacing = resolved.pairSpacing
            paragraphStyle.lineSpacing = resolvedParagraph.lineSpacing

            var attributes: [NSAttributedString.Key: Any] = [
                .font: theme.baseFont,
                .paragraphStyle: paragraphStyle,
            ]

            // 术语文字颜色
            if let termTextColor = resolved.termTextColor {
                attributes[.foregroundColor] = termTextColor
            }

            // 术语字体：优先使用配置字体，否则正文 + bold
            if let termFont = resolved.termFont {
                attributes[.font] = termFont
            } else if let base = theme.baseFont as? XMFont {
                #if canImport(UIKit)
                if let boldDesc = base.fontDescriptor.withSymbolicTraits(.traitBold) {
                    attributes[.font] = XMFont(descriptor: boldDesc, size: base.pointSize)
                }
                #elseif canImport(AppKit)
                attributes[.font] = NSFontManager.shared.convert(base, toHaveTrait: .boldFontMask)
                #endif
            }

            attributes[.xmarkupTag] = "definitionTerm"
            attributes[.xmarkupBlockKind] = "definitionTerm"
            return NSMutableAttributedString(string: block.text, attributes: attributes)

        case .definitionDescription:
            // 缩进
            paragraphStyle.headIndent = resolved.descriptionIndent
            paragraphStyle.firstLineHeadIndent = resolved.descriptionIndent

            // 段落间距
            let resolvedParagraph = theme.paragraph.resolved(for: block, context: context)
            paragraphStyle.paragraphSpacingBefore = resolvedParagraph.spacingBefore
            paragraphStyle.paragraphSpacing = resolvedParagraph.spacingAfter
            paragraphStyle.lineSpacing = resolvedParagraph.lineSpacing

            var attributes: [NSAttributedString.Key: Any] = [
                .font: theme.baseFont,
                .paragraphStyle: paragraphStyle,
            ]

            // 可选颜色
            if let color = resolved.descriptionColor {
                attributes[.foregroundColor] = color
            }

            attributes[.xmarkupTag] = "definitionDescription"
            attributes[.xmarkupBlockKind] = "definitionDescription"
            return NSMutableAttributedString(string: block.text, attributes: attributes)

        default:
            return nil
        }
    }
}
