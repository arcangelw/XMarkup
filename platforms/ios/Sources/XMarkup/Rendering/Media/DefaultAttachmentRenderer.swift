import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 默认附件渲染器 — 处理 image/video/audio 块的 NSTextAttachment 创建
///
/// 使用 `context.theme.media` 策略决定附件的创建方式。
public struct DefaultAttachmentRenderer: BlockRendering, Sendable {
    public init() {}

    public func render(block: MarkupBlock, context: RenderingContext) -> NSMutableAttributedString? {
        guard let attachment = block.attachment else { return nil }

        // 构建块级基础属性
        var baseAttributes: [NSAttributedString.Key: Any] = [:]
        baseAttributes[.font] = context.theme.baseFont

        // 设置自定义 key
        let blockKindName = blockKindName(for: block.kind)
        baseAttributes[.xmarkupTag] = blockKindName
        baseAttributes[.xmarkupBlockKind] = blockKindName

        return renderAttachmentBlock(block, attachment: attachment, theme: context.theme, baseAttributes: baseAttributes)
    }

    // MARK: - Attachment Rendering

    private func renderAttachmentBlock(
        _ block: MarkupBlock,
        attachment: MarkupAttachment,
        theme: MarkupTheme,
        baseAttributes: [NSAttributedString.Key: Any]
    ) -> NSMutableAttributedString {
        let nsAttachment: NSTextAttachment

        switch theme.media {
        case .placeholder:
            nsAttachment = createPlaceholderAttachment(
                content: attachment.content,
                suggestedSize: attachment.suggestedSize
            )
        case .imageProvider(let provider):
            let src = extractSrc(from: attachment.content)
            if let image = provider(src), image.size.width > 0, image.size.height > 0 {
                let attach = NSTextAttachment()
                attach.image = image
                let aspectRatio = image.size.height / max(image.size.width, 1)
                let displayWidth = max(attachment.suggestedSize.width, 1)
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

        let result = NSMutableAttributedString(string: "\u{FFFC}", attributes: baseAttributes)
        result.addAttribute(.xmarkupAttachmentRef,
                            value: srcIdentifier(from: attachment.content),
                            range: NSRange(location: 0, length: result.length))
        result.addAttribute(.xmarkupTag,
                            value: blockKindName(for: block.kind),
                            range: NSRange(location: 0, length: result.length))
        result.addAttribute(.attachment, value: nsAttachment,
                            range: NSRange(location: 0, length: result.length))

        return result
    }

    // MARK: - Placeholder

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
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.systemGray.withAlphaComponent(0.1).setFill()
            rect.fill()
            let symbolSize = symbol.size
            symbol.draw(
                at: NSPoint(x: (size.width - symbolSize.width) / 2, y: (size.height - symbolSize.height) / 2),
                from: NSRect.zero,
                operation: .sourceOver,
                fraction: 1.0
            )
            return true
        }
        return image
        #endif
    }
}
