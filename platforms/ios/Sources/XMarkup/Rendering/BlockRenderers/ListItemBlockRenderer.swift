import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 列表项渲染器
///
/// 两种模式（由 `ListTheme.markerMode` 控制）：
/// - `.automatic`（默认）：NSTextList 原生标记，文本干净。连续编号等由 UI 层处理。
/// - `.manual`：文本前缀（"•\t" / "1.\t"），管线自动偏移 inline。
public struct ListItemBlockRenderer: BlockRendering, Sendable {
    public init() {}

    public func render(block: MarkupBlock, context: inout RenderingContext) -> NSMutableAttributedString? {
        guard case .listItem(let isOrdered, let indentLevel) = block.kind else { return nil }

        let theme = context.theme
        let listCtx = context.listContext
        let resolvedList = theme.list.resolved(for: block, context: context)

        let indentUnit = resolvedList.indentUnit
        let markerPadding = resolvedList.markerPadding
        let useManual = resolvedList.markerMode == .manual

        let paragraphStyle = NSMutableParagraphStyle()
        let displayText: String

        if useManual {
            // ── 手动模式：文本前缀 ──
            let prefix: String
            if isOrdered {
                let index = listCtx?.orderedItemIndex ?? 1
                prefix = "\(index)\(resolvedList.orderedMarkerSuffix)\t"
            } else {
                prefix = "\(bulletChar(for: resolvedList.unorderedMarker))\t"
            }
            displayText = prefix + block.text
            context.textPrefixLength = prefix.utf16.count

            let baseIndent = CGFloat(indentLevel) * indentUnit + markerPadding
            paragraphStyle.firstLineHeadIndent = baseIndent
            paragraphStyle.headIndent = baseIndent + indentUnit
            paragraphStyle.tabStops = [
                NSTextTab(textAlignment: .left, location: baseIndent + indentUnit, options: [:])
            ]
        } else {
            // ── 自动模式：NSTextList 原生标记 ──
            displayText = block.text

            if let shared = listCtx?.textLists {
                paragraphStyle.textLists = shared
            } else {
                let markerType = isOrdered ? resolvedList.orderedMarker : resolvedList.unorderedMarker
                let format = ListTheme.markerFormat(for: markerType)
                var lists: [NSTextList] = []
                for level in 0...indentLevel {
                    let fmt: NSTextList.MarkerFormat
                    if level == 0 {
                        fmt = format
                    } else {
                        let nestedType = isOrdered ? resolvedList.nestedOrderedMarker : resolvedList.nestedUnorderedMarker
                        fmt = ListTheme.markerFormat(for: nestedType)
                    }
                    lists.append(NSTextList(markerFormat: fmt, options: 0))
                }
                paragraphStyle.textLists = lists
            }

            let visualLevel = max(0, indentLevel - 1)
            paragraphStyle.firstLineHeadIndent = CGFloat(visualLevel) * indentUnit + markerPadding
            paragraphStyle.headIndent = CGFloat(visualLevel + 1) * indentUnit + markerPadding
            paragraphStyle.tabStops = [
                NSTextTab(textAlignment: .left, location: CGFloat(visualLevel + 1) * indentUnit + markerPadding, options: [:])
            ]
        }

        // 行间距
        paragraphStyle.lineSpacing = theme.paragraph.lineSpacing

        // 组间距
        if listCtx?.isFirstInGroup ?? true {
            paragraphStyle.paragraphSpacingBefore = resolvedList.groupSpacingBefore
                ?? theme.paragraph.resolved(for: block, context: context).spacingBefore
        } else {
            paragraphStyle.paragraphSpacingBefore = 0
        }
        if listCtx?.isLastInGroup ?? true {
            paragraphStyle.paragraphSpacing = resolvedList.groupSpacingAfter
                ?? theme.paragraph.resolved(for: block, context: context).spacingAfter
        } else {
            paragraphStyle.paragraphSpacing = resolvedList.itemSpacing
        }

        var attributes: [NSAttributedString.Key: Any] = [
            .font: theme.baseFont,
            .paragraphStyle: paragraphStyle,
        ]

        let blockKindName = blockKindName(for: block.kind)
        attributes[.xmarkupTag] = blockKindName
        attributes[.xmarkupBlockKind] = blockKindName
        attributes[.xmarkupListItemInfo] = "\(isOrdered ? "ordered" : "unordered"):\(indentLevel)"

        return NSMutableAttributedString(string: displayText, attributes: attributes)
    }

    private func bulletChar(for type: ListTheme.MarkerType) -> String {
        switch type {
        case .disc:    return "\u{2022}"   // •
        case .circle:  return "\u{25E6}"   // ◦
        case .square:  return "\u{25AA}"   // ▪
        case .hyphen:  return "\u{2013}"   // –
        case .check:   return "\u{2713}"   // ✓
        case .box:     return "\u{2610}"   // ☐
        case .diamond: return "\u{25C6}"   // ◆
        default:       return "\u{2022}"   // •
        }
    }
}
