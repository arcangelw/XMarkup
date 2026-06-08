import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension MarkupDocument {

    /// 将文档转换为 AttributedString
    ///
    /// 性能策略：按 block 分段构建（init(String, attributes: AttributeContainer)），
    /// 然后一次性 append 拼接。利用 AttributedString 的 COW 优化。
    public func render(theme: MarkupTheme = .default) -> AttributedString {
        guard !blocks.isEmpty else {
            return AttributedString("")
        }

        var result = AttributedString("")

        for (index, block) in blocks.enumerated() {
            if index > 0 {
                result.append(AttributedString("\n"))
            }
            result.append(renderBlock(block, theme: theme))
        }

        return result
    }
}

// MARK: - Block Rendering

private func renderBlock(_ block: MarkupBlock, theme: MarkupTheme) -> AttributedString {
    // 1. 构建块级基础属性
    var baseAttributes = AttributeContainer()
    #if canImport(UIKit)
    baseAttributes.uiKit.font = theme.baseFont
    #elseif canImport(AppKit)
    baseAttributes.appKit.font = theme.baseFont
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

    // 4. 处理媒体附件
    if let attachment = block.attachment {
        return renderAttachmentBlock(block, attachment: attachment, theme: theme, baseAttributes: baseAttributes)
    }

    // 5. 构建段落 AttributedString
    var attr = AttributedString(block.text, attributes: baseAttributes)

    // 6. 应用内联样式
    for inline in block.inlines {
        applyInlineAttributes(inline, theme: theme, to: &attr, blockText: block.text)
    }

    // 7. 应用主题 tagStyles 覆盖
    applyThemeOverrides(for: block, theme: theme, to: &attr)

    return attr
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
        case .h1: scale = theme.headingScale.h1
        case .h2: scale = theme.headingScale.h2
        case .h3: scale = theme.headingScale.h3
        case .h4: scale = theme.headingScale.h4
        case .h5: scale = theme.headingScale.h5
        case .h6: scale = theme.headingScale.h6
        }
        let fontSize = theme.baseFont.pointSize * scale
        #if canImport(UIKit)
        if let boldDescriptor = theme.baseFont.fontDescriptor.withSymbolicTraits(traitBold) {
            attributes.uiKit.font = UIFont(descriptor: boldDescriptor, size: fontSize)
        }
        #elseif canImport(AppKit)
        let boldDescriptor = theme.baseFont.fontDescriptor.withSymbolicTraits(.bold)
        if let font = NSFont(descriptor: boldDescriptor, size: fontSize) {
            attributes.appKit.font = font
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

// MARK: - Inline Attributes

private func applyInlineAttributes(
    _ inline: MarkupInline,
    theme: MarkupTheme,
    to attr: inout AttributedString,
    blockText: String
) {
    // inline.range 是 UTF-16 NSRange（相对于块文本起始位置）
    // 通过 String.Index 中转后使用 character offset 定位 AttributedString，
    // 避免 Range(NSRange, in: AttributedString) 在 emoji 场景下可能出现的边界错位。
    let attrRange: Range<AttributedString.Index>
    do {
        guard let stringRange = Range(inline.range, in: blockText) else { return }
        let charOffset = blockText.distance(from: blockText.startIndex, to: stringRange.lowerBound)
        let charLength = blockText.distance(from: stringRange.lowerBound, to: stringRange.upperBound)
        guard charLength > 0 else { return }
        let start = attr.index(attr.startIndex, offsetByCharacters: charOffset)
        let end = attr.index(start, offsetByCharacters: charLength)
        attrRange = start..<end
    }

    switch inline.kind {
    case .bold:
        applyFontTrait(traitBold, to: attrRange, in: &attr)

    case .italic:
        applyFontTrait(traitItalic, to: attrRange, in: &attr)

    case .underline:
        #if canImport(UIKit)
        attr[attrRange].uiKit.underlineStyle = .single
        #elseif canImport(AppKit)
        attr[attrRange].appKit.underlineStyle = .single
        #endif

    case .strikethrough:
        #if canImport(UIKit)
        attr[attrRange].uiKit.strikethroughStyle = .single
        #elseif canImport(AppKit)
        attr[attrRange].appKit.strikethroughStyle = .single
        #endif

    case .code:
        #if canImport(UIKit)
        attr[attrRange].uiKit.font = UIFont.monospacedSystemFont(
            ofSize: theme.baseFont.pointSize, weight: .regular
        )
        #elseif canImport(AppKit)
        attr[attrRange].appKit.font = NSFont.monospacedSystemFont(
            ofSize: theme.baseFont.pointSize, weight: .regular
        )
        #endif

    case .mark:
        break  // 颜色由主题 tagStyles 覆盖

    case .link(let url):
        #if canImport(UIKit)
        attr[attrRange].uiKit.foregroundColor = .systemBlue
        #elseif canImport(AppKit)
        attr[attrRange].appKit.foregroundColor = .linkColor
        #endif
        attr[attrRange].link = URL(string: url)
        attr[attrRange][XMarkupLinkURLKey.self] = url

    case .subscriptText:
        break  // P2

    case .superscript:
        break  // P2

    case .span(let styles):
        for style in styles {
            applyInlineStyle(style, to: attrRange, in: &attr)
        }
    }

    // 为所有内联元素设置自定义 tag
    let tagName = inlineKindName(for: inline.kind)
    attr[attrRange][XMarkupTagKey.self] = tagName
}

private func applyFontTrait(
    _ trait: XMFontDescriptor.SymbolicTraits,
    to range: Range<AttributedString.Index>,
    in attr: inout AttributedString
) {
    for run in attr[range].runs {
        #if canImport(UIKit)
        if let font = run.uiKit.font {
            var traits = font.fontDescriptor.symbolicTraits
            traits.insert(trait)
            if let descriptor = font.fontDescriptor.withSymbolicTraits(traits) {
                let newFont = UIFont(descriptor: descriptor, size: font.pointSize)
                attr[run.range].uiKit.font = newFont
            }
        }
        #elseif canImport(AppKit)
        if let font = run.appKit.font {
            var traits = font.fontDescriptor.symbolicTraits
            traits.insert(trait)
            let descriptor = font.fontDescriptor.withSymbolicTraits(traits)
            if let newFont = NSFont(descriptor: descriptor, size: font.pointSize) {
                attr[run.range].appKit.font = newFont
            }
        }
        #endif
    }
}

private func applyInlineStyle(
    _ style: InlineStyle,
    to range: Range<AttributedString.Index>,
    in attr: inout AttributedString
) {
    switch style {
    case .foregroundColor(let hex):
        if let color = ColorParser.parse(hex) {
            #if canImport(UIKit)
            attr[range].uiKit.foregroundColor = color
            #elseif canImport(AppKit)
            attr[range].appKit.foregroundColor = color
            #endif
        }
    case .backgroundColor(let hex):
        if let color = ColorParser.parse(hex) {
            #if canImport(UIKit)
            attr[range].uiKit.backgroundColor = color
            #elseif canImport(AppKit)
            attr[range].appKit.backgroundColor = color
            #endif
        }
    case .fontSize(let size):
        for run in attr[range].runs {
            #if canImport(UIKit)
            if let font = run.uiKit.font {
                let newFont = UIFont(descriptor: font.fontDescriptor, size: CGFloat(size))
                attr[run.range].uiKit.font = newFont
            }
            #elseif canImport(AppKit)
            if let font = run.appKit.font {
                if let newFont = NSFont(descriptor: font.fontDescriptor, size: CGFloat(size)) {
                    attr[run.range].appKit.font = newFont
                }
            }
            #endif
        }
    case .fontStyle(let fontStyle):
        if fontStyle == "italic" {
            applyFontTrait(traitItalic, to: range, in: &attr)
        }
    case .textDecoration(let decoration):
        if decoration == "underline" {
            #if canImport(UIKit)
            attr[range].uiKit.underlineStyle = .single
            #elseif canImport(AppKit)
            attr[range].appKit.underlineStyle = .single
            #endif
        } else if decoration == "line-through" {
            #if canImport(UIKit)
            attr[range].uiKit.strikethroughStyle = .single
            #elseif canImport(AppKit)
            attr[range].appKit.strikethroughStyle = .single
            #endif
        }
    case .fontWeight, .lineHeight, .letterSpacing:
        break  // P2
    }
}

// MARK: - Theme Overrides

private func applyThemeOverrides(
    for block: MarkupBlock,
    theme: MarkupTheme,
    to attr: inout AttributedString
) {
    // 块级主题覆盖
    if let blockKey = blockStyleKey(for: block.kind),
       let container = theme.tagStyles[blockKey] {
        let fullRange = attr.startIndex..<attr.endIndex
        mergeAttributeContainer(container, into: &attr, range: fullRange)
    }

    // 内联主题覆盖
    for inline in block.inlines {
        if let inlineKey = inlineStyleKey(for: inline.kind),
           let container = theme.tagStyles[inlineKey] {
            // inline.range 是 UTF-16 NSRange（相对于块文本起始位置）
            // 通过 String.Index 中转，确保 emoji 场景不出现边界错位
            guard let stringRange = Range(inline.range, in: block.text) else { continue }
            let charOffset = block.text.distance(from: block.text.startIndex, to: stringRange.lowerBound)
            let charLength = block.text.distance(from: stringRange.lowerBound, to: stringRange.upperBound)
            guard charLength > 0 else { continue }
            let start = attr.index(attr.startIndex, offsetByCharacters: charOffset)
            let end = attr.index(start, offsetByCharacters: charLength)
            mergeAttributeContainer(container, into: &attr, range: start..<end)
        }
    }
}

private func mergeAttributeContainer(
    _ container: AttributeContainer,
    into attr: inout AttributedString,
    range: Range<AttributedString.Index>
) {
    #if canImport(UIKit)
    if let font = container.uiKit.font {
        attr[range].uiKit.font = font
    }
    if let color = container.uiKit.foregroundColor {
        attr[range].uiKit.foregroundColor = color
    }
    if let bgColor = container.uiKit.backgroundColor {
        attr[range].uiKit.backgroundColor = bgColor
    }
    #elseif canImport(AppKit)
    if let font = container.appKit.font {
        attr[range].appKit.font = font
    }
    if let color = container.appKit.foregroundColor {
        attr[range].appKit.foregroundColor = color
    }
    if let bgColor = container.appKit.backgroundColor {
        attr[range].appKit.backgroundColor = bgColor
    }
    #endif
}

// MARK: - Attachment Rendering

private func renderAttachmentBlock(
    _ block: MarkupBlock,
    attachment: MarkupAttachment,
    theme: MarkupTheme,
    baseAttributes: AttributeContainer
) -> AttributedString {
    let nsAttachment: NSTextAttachment

    switch theme.mediaStrategy {
    case .placeholder:
        nsAttachment = createPlaceholderAttachment(
            content: attachment.content,
            suggestedSize: attachment.suggestedSize
        )
    case .imageProvider(let provider):
        let src = extractSrc(from: attachment.content)
        if let image = provider(src) {
            let attach = NSTextAttachment()
            attach.image = image
            let aspectRatio = image.size.height / max(image.size.width, 1)
            let displayWidth = attachment.suggestedSize.width
            let displaySize = CGSize(width: displayWidth, height: displayWidth * aspectRatio)
            attach.bounds = CGRect(origin: .zero, size: displaySize)
            nsAttachment = attach
        } else {
            nsAttachment = createPlaceholderAttachment(
                content: attachment.content,
                suggestedSize: attachment.suggestedSize
            )
        }
    case .customAttachment(let factory):
        if let custom = factory(attachment.content, attachment.suggestedSize) {
            nsAttachment = custom
        } else {
            nsAttachment = createPlaceholderAttachment(
                content: attachment.content,
                suggestedSize: attachment.suggestedSize
            )
        }
    }

    // 通过 NSAttributedString 中间步骤嵌入 NSTextAttachment
    var attr = AttributedString("\u{FFFC}", attributes: baseAttributes)
    attr[XMarkupAttachmentRefKey.self] = srcIdentifier(from: attachment.content)
    attr[XMarkupTagKey.self] = blockKindName(for: block.kind)

    let nsAttr = NSMutableAttributedString(attributedString: NSAttributedString(attr))
    let attachmentAttr = NSAttributedString(attachment: nsAttachment)
    let nsRange = (nsAttr.string as NSString).range(of: "\u{FFFC}")
    if nsRange.location != NSNotFound {
        nsAttr.replaceCharacters(in: nsRange, with: attachmentAttr)
    }

    return AttributedString(nsAttr)
}

private func createPlaceholderAttachment(
    content: AttachmentContent,
    suggestedSize: CGSize
) -> NSTextAttachment {
    let symbolName: String
    switch content {
    case .image: symbolName = "photo"
    case .video: symbolName = "play.rectangle"
    case .audio: symbolName = "waveform"
    case .custom: symbolName = "square"
    }

    let size = suggestedSize.width > 0 ? suggestedSize : CGSize(width: 200, height: 150)
    let image = createPlaceholderImage(systemName: symbolName, size: size)

    let attachment = NSTextAttachment()
    attachment.image = image
    attachment.bounds = CGRect(origin: .zero, size: size)
    return attachment
}

private func createPlaceholderImage(systemName: String, size: CGSize) -> XMImage {
    #if canImport(UIKit)
    let symbolConfig = UIImage.SymbolConfiguration(pointSize: min(size.width, size.height) * 0.3)
    let symbol = UIImage(systemName: systemName, withConfiguration: symbolConfig) ?? UIImage()
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { context in
        UIColor.systemGray.withAlphaComponent(0.1).setFill()
        context.fill(CGRect(origin: .zero, size: size))
        let symbolSize = symbol.size
        symbol.draw(at: CGPoint(
            x: (size.width - symbolSize.width) / 2,
            y: (size.height - symbolSize.height) / 2
        ))
    }
    #elseif canImport(AppKit)
    let symbol = NSImage(systemSymbolName: systemName, accessibilityDescription: nil) ?? NSImage(size: size)
    let image = NSImage(size: size)
    image.lockFocus()
    NSColor.systemGray.withAlphaComponent(0.1).setFill()
    NSRect(origin: .zero, size: size).fill()
    let symbolSize = symbol.size
    symbol.draw(
        at: NSPoint(x: (size.width - symbolSize.width) / 2, y: (size.height - symbolSize.height) / 2),
        from: .zero,
        operation: .sourceOver,
        fraction: 1.0
    )
    image.unlockFocus()
    return image
    #endif
}

// MARK: - Name Mappings

private func blockKindName(for kind: BlockKind) -> String {
    switch kind {
    case .paragraph: return "paragraph"
    case .heading(let level): return "heading\(level.rawValue)"
    case .blockquote: return "blockquote"
    case .preformatted: return "preformatted"
    case .listItem: return "listItem"
    case .division: return "division"
    case .horizontalRule: return "horizontalRule"
    case .table: return "table"
    }
}

private func inlineKindName(for kind: InlineKind) -> String {
    switch kind {
    case .bold: return "bold"
    case .italic: return "italic"
    case .underline: return "underline"
    case .strikethrough: return "strikethrough"
    case .code: return "code"
    case .mark: return "mark"
    case .link: return "link"
    case .subscriptText: return "subscript"
    case .superscript: return "superscript"
    case .span: return "span"
    }
}

private func blockStyleKey(for kind: BlockKind) -> TagStyleKey? {
    switch kind {
    case .paragraph: return .paragraph
    case .heading: return .heading
    case .blockquote: return .blockquote
    case .preformatted: return .preformatted
    case .listItem: return .listItem
    case .division: return .division
    case .horizontalRule: return .horizontalRule
    case .table: return nil
    }
}

private func inlineStyleKey(for kind: InlineKind) -> TagStyleKey? {
    switch kind {
    case .bold: return .bold
    case .italic: return .italic
    case .underline: return .underline
    case .strikethrough: return .strikethrough
    case .code: return .code
    case .mark: return .mark
    case .link: return .link
    case .subscriptText, .superscript: return nil
    case .span: return nil
    }
}

private func extractSrc(from content: AttachmentContent) -> String {
    switch content {
    case .image(let src), .video(let src), .audio(let src): return src
    case .custom(_, let metadata): return metadata["src"] ?? ""
    }
}

private func srcIdentifier(from content: AttachmentContent) -> String {
    switch content {
    case .image(let src): return "image:\(src)"
    case .video(let src): return "video:\(src)"
    case .audio(let src): return "audio:\(src)"
    case .custom(let type, _): return "custom:\(type)"
    }
}

// MARK: - 跨平台字体 Trait 常量

#if canImport(UIKit)
private let traitBold: UIFontDescriptor.SymbolicTraits = .traitBold
private let traitItalic: UIFontDescriptor.SymbolicTraits = .traitItalic
#elseif canImport(AppKit)
private let traitBold: NSFontDescriptor.SymbolicTraits = .bold
private let traitItalic: NSFontDescriptor.SymbolicTraits = .italic
#endif
