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

    public func render(block: MarkupBlock, context: RenderingContext) -> AttributedString? {
        guard let attachment = block.attachment else { return nil }

        // 构建块级基础属性
        var baseAttributes = AttributeContainer()
        #if canImport(UIKit)
        baseAttributes.uiKit.font = context.theme.baseFont
        #elseif canImport(AppKit)
        baseAttributes.appKit.font = context.theme.baseFont
        #endif

        // 设置自定义 key
        let blockKindName = blockKindName(for: block.kind)
        baseAttributes[XMarkupTagKey.self] = blockKindName
        baseAttributes[XMarkupBlockKindKey.self] = blockKindName

        return renderAttachmentBlock(block, attachment: attachment, theme: context.theme, baseAttributes: baseAttributes)
    }
}
