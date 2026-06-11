import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 默认块级渲染器 — 处理除 table 和 media attachment 外的所有 block 类型
///
/// 只负责块级渲染（字体、间距、缩进、XMarkupScope key、HR）。
/// inline 渲染由 RenderPipeline 在 block 渲染完成后通过 inlineRenderers 调度。
/// 不处理 `.table`（由 DefaultTableRenderer 处理）和带 attachment 的 block（由 DefaultAttachmentRenderer 处理）。
public struct DefaultBlockRenderer: BlockRendering, Sendable {
    public init() {}

    public func render(block: MarkupBlock, context: RenderingContext) -> AttributedString? {
        // table 由 DefaultTableRenderer 处理
        if case .table = block.kind { return nil }

        // media attachment 由 DefaultAttachmentRenderer 处理
        if block.attachment != nil { return nil }

        // 从 sharedState 读取列表组信息（由 RenderPipeline 分析后注入）
        let sharedLists = context.sharedState[RenderPipeline.SharedStateKeys.listTextLists] as? [NSTextList]
        let isFirst = context.sharedState[RenderPipeline.SharedStateKeys.isFirstInListGroup] as? Bool ?? false
        let isLast = context.sharedState[RenderPipeline.SharedStateKeys.isLastInListGroup] as? Bool ?? false

        let theme = context.theme

        // 1. 构建块级基础属性
        var baseAttributes = AttributeContainer()
        #if canImport(UIKit)
        baseAttributes.uiKit.font = theme.baseFont
        #elseif canImport(AppKit)
        baseAttributes.appKit.font = theme.baseFont
        #endif

        // 1.5 应用段落排版间距
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacingBefore = theme.paragraph.spacingBefore
        paragraphStyle.paragraphSpacing = theme.paragraph.spacingAfter
        paragraphStyle.lineSpacing = theme.paragraph.lineSpacing

        // 块级特定排版
        switch block.kind {
        case let .heading(level):
            let spacingScale: CGFloat
            switch level {
            case .h1: spacingScale = 0.50
            case .h2: spacingScale = 0.60
            case .h3: spacingScale = 0.70
            case .h4: spacingScale = 0.80
            case .h5: spacingScale = 0.90
            case .h6: spacingScale = 1.00
            }
            let headingSpacing = theme.baseFont.pointSize * spacingScale
            paragraphStyle.paragraphSpacingBefore = headingSpacing
            paragraphStyle.paragraphSpacing = headingSpacing * 0.5
        case .blockquote:
            paragraphStyle.headIndent = theme.blockquote.indent
            paragraphStyle.firstLineHeadIndent = theme.blockquote.indent
        case .listItem(let isOrdered, let indentLevel):
            // 优先使用共享的 NSTextList 实例（同一组列表项自动编号）
            if let shared = sharedLists {
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

            if isFirst {
                paragraphStyle.paragraphSpacingBefore = theme.paragraph.spacingBefore
            } else {
                paragraphStyle.paragraphSpacingBefore = 0
            }
            if isLast {
                paragraphStyle.paragraphSpacing = theme.paragraph.spacingAfter
            } else {
                paragraphStyle.paragraphSpacing = 2
            }
        case .preformatted:
            #if canImport(UIKit)
            paragraphStyle.lineBreakMode = .byCharWrapping
            #endif
        default:
            break
        }

        #if canImport(UIKit)
        baseAttributes.uiKit.paragraphStyle = paragraphStyle
        #elseif canImport(AppKit)
        baseAttributes.appKit.paragraphStyle = paragraphStyle
        #endif

        // 2. 根据 block.kind 调整属性
        applyBlockKindAttributes(kind: block.kind, theme: theme, to: &baseAttributes)

        // 3. 设置自定义 XMarkupScope 属性
        let blockKindName = blockKindName(for: block.kind)
        baseAttributes[XMarkupTagKey.self] = blockKindName
        baseAttributes[XMarkupBlockKindKey.self] = blockKindName

        switch block.kind {
        case let .heading(level):
            baseAttributes[XMarkupHeadingLevelKey.self] = level.rawValue
        case let .listItem(isOrdered, indentLevel):
            baseAttributes[XMarkupListItemInfoKey.self] = "\(isOrdered ? "ordered" : "unordered"):\(indentLevel)"
        default:
            break
        }

        // 4. 处理 hr 分隔线（NSTextAttachment 矢量线条，双平台统一）
        if case .horizontalRule = block.kind {
            let attachment = NSTextAttachment()
            let lineWidth: CGFloat = 300
            let lineHeight: CGFloat = 1
            #if canImport(UIKit)
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: lineWidth, height: lineHeight))
            attachment.image = renderer.image { ctx in
                UIColor.separator.setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: lineWidth, height: lineHeight))
            }
            #elseif canImport(AppKit)
            let image = NSImage(size: NSSize(width: lineWidth, height: lineHeight))
            image.lockFocus()
            NSColor.separatorColor.setFill()
            NSRect(x: 0, y: 0, width: lineWidth, height: lineHeight).fill()
            image.unlockFocus()
            attachment.image = image
            #endif
            attachment.bounds = CGRect(x: 0, y: 0, width: lineWidth, height: lineHeight)
            let nsAttr = NSMutableAttributedString(attachment: attachment)
            nsAttr.addAttribute(.paragraphStyle, value: paragraphStyle,
                                 range: NSRange(location: 0, length: nsAttr.length))
            nsAttr.addAttribute(NSAttributedString.Key(XMarkupBlockKindKey.name),
                                 value: "horizontalRule",
                                 range: NSRange(location: 0, length: nsAttr.length))
            return AttributedString(nsAttr)
        }

        // 5. 构建段落 AttributedString（不含 inline 渲染）
        let blockText = block.text
        return AttributedString(blockText, attributes: baseAttributes)
    }

    // MARK: - Block Kind Attributes

    private func applyBlockKindAttributes(
        kind: BlockKind,
        theme: MarkupTheme,
        to attributes: inout AttributeContainer
    ) {
        switch kind {
        case let .heading(level):
            let scale: CGFloat
            switch level {
            case .h1: scale = theme.heading.scale.h1
            case .h2: scale = theme.heading.scale.h2
            case .h3: scale = theme.heading.scale.h3
            case .h4: scale = theme.heading.scale.h4
            case .h5: scale = theme.heading.scale.h5
            case .h6: scale = theme.heading.scale.h6
            }
            let fontSize = theme.baseFont.pointSize * scale
            #if canImport(UIKit)
            if let boldDescriptor = theme.baseFont.fontDescriptor.withSymbolicTraits(traitBold) {
                attributes.uiKit.font = UIFont(descriptor: boldDescriptor, size: fontSize)
            } else {
                attributes.uiKit.font = UIFont.systemFont(ofSize: fontSize, weight: .bold)
            }
            #elseif canImport(AppKit)
            let boldDescriptor = theme.baseFont.fontDescriptor.withSymbolicTraits(.bold)
            if let font = NSFont(descriptor: boldDescriptor, size: fontSize) {
                attributes.appKit.font = font
            } else {
                attributes.appKit.font = NSFont.boldSystemFont(ofSize: fontSize)
            }
            #endif

        case .preformatted:
            #if canImport(UIKit)
            attributes.uiKit.font = UIFont.monospacedSystemFont(ofSize: theme.baseFont.pointSize, weight: .regular)
            #elseif canImport(AppKit)
            attributes.appKit.font = NSFont.monospacedSystemFont(ofSize: theme.baseFont.pointSize, weight: .regular)
            #endif

        case .horizontalRule:
            break

        default:
            break
        }
    }
}
