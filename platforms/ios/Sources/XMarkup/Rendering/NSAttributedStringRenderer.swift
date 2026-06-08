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
        return NSAttributedString(attributedString: nsAttr)
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
    private func transferCustomKeys(from attr: AttributedString, to nsAttr: NSMutableAttributedString) {
        var offset = 0
        for run in attr.runs {
            let runLength = attr[run.range].characters.count
            let nsRange = NSRange(location: offset, length: runLength)
            offset += runLength

            guard runLength > 0 else { continue }

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
