import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 零成本桥接渲染器
/// 将 AttributedString（含自定义 XMarkup key）转为 NSAttributedString，
/// 同时手动转移自定义 key 以确保它们在 NS 层可读。
public struct NSAttributedStringRenderer: MarkupRenderer, Sendable {
    public init() {}

    public func render(_ attributed: AttributedString) -> NSAttributedString {
        let nsAttr = NSMutableAttributedString(attributedString: NSAttributedString(attributed))
        transferCustomKeys(from: attributed, to: nsAttr)
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

    /// 将自定义 XMarkupScope key 手动转移到 NSAttributedString
    ///
    /// - Note: 必须使用 `runText.utf16.count` 而非 `characters.count`，
    ///         因为 `NSRange` 的单位是 UTF-16 码元，而 `characters.count`
    ///         返回的是 Extended Grapheme Cluster 数量，两者在多字节 emoji
    ///         场景下不一致（例如 🔄 = 2 UTF-16 码元但 1 个 grapheme）。
    private func transferCustomKeys(from attr: AttributedString, to nsAttr: NSMutableAttributedString) {
        var offset = 0
        for run in attr.runs {
            let runText = String(attr[run.range].characters)
            let utf16Len = runText.utf16.count
            let nsRange = NSRange(location: offset, length: utf16Len)
            offset += utf16Len

            guard utf16Len > 0 else { continue }

            // 逐个检查自定义 key
            if let value = run[XMarkupTagKey.self] {
                nsAttr.addAttribute(NSAttributedString.Key(XMarkupTagKey.name), value: value, range: nsRange)
            }
            if let value = run[XMarkupBlockKindKey.self] {
                nsAttr.addAttribute(NSAttributedString.Key(XMarkupBlockKindKey.name), value: value, range: nsRange)
            }
            if let value = run[XMarkupLinkURLKey.self] {
                nsAttr.addAttribute(NSAttributedString.Key(XMarkupLinkURLKey.name), value: value, range: nsRange)
            }
            if let value = run[XMarkupHeadingLevelKey.self] {
                nsAttr.addAttribute(NSAttributedString.Key(XMarkupHeadingLevelKey.name), value: value, range: nsRange)
            }
            if let value = run[XMarkupListItemInfoKey.self] {
                nsAttr.addAttribute(NSAttributedString.Key(XMarkupListItemInfoKey.name), value: value, range: nsRange)
            }
            if let value = run[XMarkupAttachmentRefKey.self] {
                nsAttr.addAttribute(NSAttributedString.Key(XMarkupAttachmentRefKey.name), value: value, range: nsRange)
            }
        }
    }
}
