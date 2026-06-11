import Foundation
import XMarkup

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 平台视觉增强插件 — 读取 XMarkupBlockKindKey 追加平台特定视觉属性
///
/// 在 RenderPipeline 的 NSAttributedString 增强阶段执行，
/// 替代旧的 XMarkupEnhancedRenderer（合并 key 转移 + 视觉增强的双功能类）。
///
/// macOS：为 blockquote 添加 NSTextBlock（左边框），为 pre 添加 NSTextBlock（背景+padding）。
/// iOS：视觉增强由 BlockquoteLayoutManager（view 层）完成，此处不追加额外属性。
public struct PlatformEnhancementPlugin: NSAttributedStringProcessing, Sendable {
    public init() {}

    public func enhance(_ nsAttr: NSMutableAttributedString, context: RenderingContext) {
        #if canImport(AppKit) && !canImport(UIKit)
        let key = NSAttributedString.Key(XMarkupBlockKindKey.name)
        let fullRange = NSRange(location: 0, length: nsAttr.length)
        nsAttr.enumerateAttribute(key, in: fullRange) { value, range, _ in
            guard let kind = value as? String else { return }
            switch kind {
            case "blockquote":
                applyBlockquoteBlock(nsAttr, range: range, config: context.theme.blockquote)
            case "preformatted":
                applyPreformattedBlock(nsAttr, range: range, config: context.theme.preformatted)
            default:
                break
            }
        }
        #endif
    }

    // MARK: - macOS 视觉增强

    #if canImport(AppKit) && !canImport(UIKit)
    private func applyBlockquoteBlock(_ nsAttr: NSMutableAttributedString, range: NSRange,
                                       config: BlockquoteTheme) {
        guard let paraStyle = nsAttr.attribute(.paragraphStyle, at: range.location,
                                                effectiveRange: nil) as? NSParagraphStyle,
              let mutable = paraStyle.mutableCopy() as? NSMutableParagraphStyle else { return }
        let block = NSTextBlock()
        block.setBorderColor(config.borderColor ?? .systemGray, for: .minX)
        block.setWidth(CGFloat(config.borderWidth), type: .absoluteValueType, for: .border, edge: .minX)
        block.setWidth(CGFloat(config.padding), type: .absoluteValueType, for: .padding)
        mutable.textBlocks = [block]
        nsAttr.addAttribute(.paragraphStyle, value: mutable, range: range)
    }

    private func applyPreformattedBlock(_ nsAttr: NSMutableAttributedString, range: NSRange,
                                         config: PreformattedTheme) {
        guard let paraStyle = nsAttr.attribute(.paragraphStyle, at: range.location,
                                                effectiveRange: nil) as? NSParagraphStyle,
              let mutable = paraStyle.mutableCopy() as? NSMutableParagraphStyle else { return }
        let block = NSTextBlock()
        block.backgroundColor = config.backgroundColor ?? .textBackgroundColor
        block.setWidth(CGFloat(config.padding), type: .absoluteValueType, for: .padding)
        mutable.textBlocks = [block]
        nsAttr.addAttribute(.paragraphStyle, value: mutable, range: range)
    }
    #endif
}
