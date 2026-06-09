import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Block Rendering

func renderBlock(_ block: MarkupBlock, theme: MarkupTheme) -> AttributedString {
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

func applyBlockKindAttributes(
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

// MARK: - Theme Overrides

func applyThemeOverrides(
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

func mergeAttributeContainer(
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
