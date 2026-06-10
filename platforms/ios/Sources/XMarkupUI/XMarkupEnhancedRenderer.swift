import Foundation
import XMarkup

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// MarkupRenderer 增强实现：在基础 key 转移的同一次遍历中应用平台视觉增强。
///
/// 读取 Core 输出的 `XMarkupBlockKindKey` 语义元数据，
/// 在 NSAttributedString 上追加平台特定的视觉属性：
/// - macOS：NSTextBlock（blockquote 左边框、pre 背景）、NSTextTable
/// - iOS：列表间距微调、表格 tab 对齐
///
/// 性能：合并 key 转移 + 视觉增强为单次遍历（方案 A）。
public struct XMarkupEnhancedRenderer: MarkupRenderer, Sendable {
    public init() {}

    public func render(_ attributed: AttributedString) -> NSAttributedString {
        let nsAttr = NSMutableAttributedString(attributedString: NSAttributedString(attributed))
        var offset = 0

        for run in attributed.runs {
            let runText = String(attributed[run.range].characters)
            let utf16Len = runText.utf16.count
            let nsRange = NSRange(location: offset, length: utf16Len)
            offset += utf16Len

            guard utf16Len > 0 else { continue }

            // 转移自定义 key
            if let value = run[XMarkupTagKey.self] {
                nsAttr.addAttribute(.init(XMarkupTagKey.name), value: value, range: nsRange)
            }
            if let value = run[XMarkupBlockKindKey.self] {
                let key = NSAttributedString.Key(XMarkupBlockKindKey.name)
                nsAttr.addAttribute(key, value: value, range: nsRange)
                // 同一次遍历中做视觉增强
                applyEnhancement(for: value, in: nsRange, to: nsAttr)
            }
            if let value = run[XMarkupLinkURLKey.self] {
                nsAttr.addAttribute(.init(XMarkupLinkURLKey.name), value: value, range: nsRange)
            }
            if let value = run[XMarkupHeadingLevelKey.self] {
                nsAttr.addAttribute(.init(XMarkupHeadingLevelKey.name), value: value, range: nsRange)
            }
            if let value = run[XMarkupListItemInfoKey.self] {
                nsAttr.addAttribute(.init(XMarkupListItemInfoKey.name), value: value, range: nsRange)
            }
            if let value = run[XMarkupAttachmentRefKey.self] {
                nsAttr.addAttribute(.init(XMarkupAttachmentRefKey.name), value: value, range: nsRange)
            }
        }
        return nsAttr
    }

    public func measure(_ attributed: AttributedString, constrainedTo width: CGFloat) -> CGSize {
        let nsAttr = render(attributed)
        let size = nsAttr.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return CGSize(width: ceil(size.width), height: ceil(size.height))
    }

    // MARK: - 平台视觉增强

    #if canImport(AppKit) && !canImport(UIKit)
    /// macOS：为 blockquote/pre 添加 NSTextBlock 视觉属性
    private func applyEnhancement(for kind: String, in range: NSRange, to nsAttr: NSMutableAttributedString) {
        switch kind {
        case "blockquote":
            guard let paraStyle = nsAttr.attribute(.paragraphStyle, at: range.location,
                                                    effectiveRange: nil) as? NSParagraphStyle,
                  let mutable = paraStyle.mutableCopy() as? NSMutableParagraphStyle else { return }
            let block = NSTextBlock()
            block.setBorderColor(.systemGray, for: .minX)
            block.setWidth(3, type: .absoluteValueType, for: .border, edge: .minX)
            block.setWidth(8, type: .absoluteValueType, for: .padding)
            mutable.textBlocks = [block]
            nsAttr.addAttribute(.paragraphStyle, value: mutable, range: range)

        case "preformatted":
            guard let paraStyle = nsAttr.attribute(.paragraphStyle, at: range.location,
                                                    effectiveRange: nil) as? NSParagraphStyle,
                  let mutable = paraStyle.mutableCopy() as? NSMutableParagraphStyle else { return }
            let block = NSTextBlock()
            block.backgroundColor = .textBackgroundColor
            block.setWidth(8, type: .absoluteValueType, for: .padding)
            mutable.textBlocks = [block]
            nsAttr.addAttribute(.paragraphStyle, value: mutable, range: range)

        default:
            break
        }
    }
    #else
    /// iOS：视觉增强由 BlockquoteLayoutManager（view 层）完成，
    /// 此处不追加额外属性。
    private func applyEnhancement(for kind: String, in range: NSRange, to nsAttr: NSMutableAttributedString) {
        // iOS 的 blockquote 竖线由 BlockquoteLayoutManager 在 drawBackground 中绘制
        // 表格的视觉渲染由 XMarkupUI 的自定义 LayoutManager 处理
    }
    #endif
}
