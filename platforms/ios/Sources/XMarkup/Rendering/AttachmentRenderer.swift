import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Attachment Rendering

func renderAttachmentBlock(
    _ block: MarkupBlock,
    attachment: MarkupAttachment,
    theme: MarkupTheme,
    baseAttributes: AttributeContainer
) -> AttributedString {
    let nsAttachment: NSTextAttachment

    switch theme.media {
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

	// 创建附件富文本：AttributedString 上设自定义 key → NS 层加 `.attachment` 属性
    var attr = AttributedString("\u{FFFC}", attributes: baseAttributes)
    attr[XMarkupAttachmentRefKey.self] = srcIdentifier(from: attachment.content)
    attr[XMarkupTagKey.self] = blockKindName(for: block.kind)

    let nsAttr = NSMutableAttributedString(attributedString: NSAttributedString(attr))
    // 直接添加 .attachment 属性到 \u{FFFC} 字符范围，无需 replaceCharacters
    // 这样自定义 key 不会被丢弃，NSAttributedStringRenderer.transferCustomKeys 能正常读取
    nsAttr.addAttribute(.attachment, value: nsAttachment,
                         range: NSRange(location: 0, length: nsAttr.length))

    return AttributedString(nsAttr)
}

func createPlaceholderAttachment(
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

func createPlaceholderImage(systemName: String, size: CGSize) -> XMImage {
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
