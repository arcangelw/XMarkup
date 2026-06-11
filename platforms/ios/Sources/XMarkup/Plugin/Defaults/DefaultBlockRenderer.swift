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
///
/// 通过调用各 typed theme 的 `resolved()` 方法消费主题配置，启用三级精度控制：
/// base → per-level override → 动态 resolve 闭包。
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

        // 解析段落主题（作为所有 block 的间距 fallback）
        let resolvedParagraph = theme.paragraph.resolved(for: block, context: context)

        // 1. 构建块级基础属性
        var baseAttributes = AttributeContainer()
        #if canImport(UIKit)
        baseAttributes.uiKit.font = theme.baseFont
        #elseif canImport(AppKit)
        baseAttributes.appKit.font = theme.baseFont
        #endif

        // 2. 构建段落排版样式
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacingBefore = resolvedParagraph.spacingBefore
        paragraphStyle.paragraphSpacing = resolvedParagraph.spacingAfter
        paragraphStyle.lineSpacing = resolvedParagraph.lineSpacing
        if let alignment = resolvedParagraph.alignment {
            paragraphStyle.alignment = alignment
        }

        // 3. 块级特定：排版 + 字体 + 文本色
        switch block.kind {
        case let .heading(level):
            // 标题间距：按级别递增
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

            // 通过 resolved() 消费标题主题（启用三级精度：base → per-level → resolve）
            if let resolved = theme.heading.resolved(for: block, baseFont: theme.baseFont, context: context) {
                let fontSize = resolved.fontSize
                if resolved.bold {
                    #if canImport(UIKit)
                    if let boldDescriptor = theme.baseFont.fontDescriptor.withSymbolicTraits(traitBold) {
                        baseAttributes.uiKit.font = UIFont(descriptor: boldDescriptor, size: fontSize)
                    } else {
                        baseAttributes.uiKit.font = UIFont.systemFont(ofSize: fontSize, weight: .bold)
                    }
                    #elseif canImport(AppKit)
                    let boldDescriptor = theme.baseFont.fontDescriptor.withSymbolicTraits(.bold)
                    if let font = NSFont(descriptor: boldDescriptor, size: fontSize) {
                        baseAttributes.appKit.font = font
                    } else {
                        baseAttributes.appKit.font = NSFont.boldSystemFont(ofSize: fontSize)
                    }
                    #endif
                } else {
                    #if canImport(UIKit)
                    baseAttributes.uiKit.font = theme.baseFont.withSize(fontSize)
                    #elseif canImport(AppKit)
                    baseAttributes.appKit.font = theme.baseFont.withSize(fontSize)
                    #endif
                }
                if let textColor = resolved.textColor {
                    #if canImport(UIKit)
                    baseAttributes.uiKit.foregroundColor = textColor
                    #elseif canImport(AppKit)
                    baseAttributes.appKit.foregroundColor = textColor
                    #endif
                }
            }

        case .blockquote:
            let resolved = theme.blockquote.resolved(for: block, context: context)
            paragraphStyle.headIndent = resolved.indent
            paragraphStyle.firstLineHeadIndent = resolved.indent
            if let textColor = resolved.textColor {
                #if canImport(UIKit)
                baseAttributes.uiKit.foregroundColor = textColor
                #elseif canImport(AppKit)
                baseAttributes.appKit.foregroundColor = textColor
                #endif
            }

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
            let resolved = theme.preformatted.resolved(for: block, context: context)
            #if canImport(UIKit)
            paragraphStyle.lineBreakMode = .byCharWrapping
            baseAttributes.uiKit.font = resolved.font
                ?? UIFont.monospacedSystemFont(ofSize: theme.baseFont.pointSize, weight: .regular)
            #elseif canImport(AppKit)
            baseAttributes.appKit.font = resolved.font
                ?? NSFont.monospacedSystemFont(ofSize: theme.baseFont.pointSize, weight: .regular)
            #endif

        case .horizontalRule:
            break

        default:
            // 普通段落：应用段落级 textColor（如有配置）
            if let textColor = resolvedParagraph.textColor {
                #if canImport(UIKit)
                baseAttributes.uiKit.foregroundColor = textColor
                #elseif canImport(AppKit)
                baseAttributes.appKit.foregroundColor = textColor
                #endif
            }
        }

        #if canImport(UIKit)
        baseAttributes.uiKit.paragraphStyle = paragraphStyle
        #elseif canImport(AppKit)
        baseAttributes.appKit.paragraphStyle = paragraphStyle
        #endif

        // 4. 设置自定义 XMarkupScope 属性
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

        // 5. 处理 hr 分隔线（NSTextAttachment 矢量线条，双平台统一）
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

        // 6. 构建段落 AttributedString（不含 inline 渲染）
        let blockText = block.text
        return AttributedString(blockText, attributes: baseAttributes)
    }
}
