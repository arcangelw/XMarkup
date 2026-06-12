import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 列表项渲染器 — 处理 listItem 的 NSTextList、缩进、间距
///
/// 通过 `context.listContext` 获取共享的 NSTextList 实例（同一组自动编号）。
public struct ListItemBlockRenderer: BlockRendering, Sendable {
    public init() {}

    public func render(block: MarkupBlock, context: RenderingContext) -> NSMutableAttributedString? {
        guard case .listItem(let isOrdered, let indentLevel) = block.kind else { return nil }

        let theme = context.theme
        let listCtx = context.listContext
        let resolvedParagraph = theme.paragraph.resolved(for: block, context: context)

        let paragraphStyle = NSMutableParagraphStyle()

        // NSTextList
        if let shared = listCtx?.textLists {
            paragraphStyle.textLists = shared
        } else {
            let format: NSTextList.MarkerFormat = isOrdered ? .decimal : .disc
            var lists: [NSTextList] = []
            for level in 0...indentLevel {
                let fmt: NSTextList.MarkerFormat = (level == 0) ? format : (isOrdered ? .decimal : .circle)
                lists.append(NSTextList(markerFormat: fmt, options: 0))
            }
            paragraphStyle.textLists = lists
        }

        let visualLevel = max(0, indentLevel - 1)
        let indentUnit = theme.list.indentUnit

        paragraphStyle.firstLineHeadIndent = CGFloat(visualLevel) * indentUnit
        paragraphStyle.headIndent = CGFloat(visualLevel + 1) * indentUnit
        paragraphStyle.tabStops = [
            NSTextTab(textAlignment: .left, location: CGFloat(visualLevel + 1) * indentUnit, options: [:])
        ]

        if listCtx?.isFirstInGroup ?? true {
            paragraphStyle.paragraphSpacingBefore = theme.paragraph.spacingBefore
        } else {
            paragraphStyle.paragraphSpacingBefore = 0
        }
        if listCtx?.isLastInGroup ?? true {
            paragraphStyle.paragraphSpacing = theme.paragraph.spacingAfter
        } else {
            paragraphStyle.paragraphSpacing = 2
        }

        var attributes: [NSAttributedString.Key: Any] = [
            .font: theme.baseFont,
            .paragraphStyle: paragraphStyle,
        ]

        let blockKindName = blockKindName(for: block.kind)
        attributes[.xmarkupTag] = blockKindName
        attributes[.xmarkupBlockKind] = blockKindName
        attributes[.xmarkupListItemInfo] = "\(isOrdered ? "ordered" : "unordered"):\(indentLevel)"

        return NSMutableAttributedString(string: block.text, attributes: attributes)
    }
}
