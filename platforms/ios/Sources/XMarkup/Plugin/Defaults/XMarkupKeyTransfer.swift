import Foundation

/// 默认 key 转移插件 — 转移 XMarkup 内置的自定义 attribute key
///
/// 将 `AttributedString` 中携带的 `XMarkupTagKey`、`XMarkupBlockKindKey` 等
/// 自定义 key 手动转移到 `NSAttributedString`，确保它们在 NS 层可读。
///
/// - Note: 必须使用 `runText.utf16.count` 而非 `characters.count`，
///         因为 `NSRange` 的单位是 UTF-16 码元，而 `characters.count`
///         返回的是 Extended Grapheme Cluster 数量，两者在多字节 emoji
///         场景下不一致（例如 🔄 = 2 UTF-16 码元但 1 个 grapheme）。
public struct XMarkupKeyTransfer: NSAttributeTransferring, Sendable {
    public init() {}

    public func transfer(
        from attributed: AttributedString,
        to nsAttr: NSMutableAttributedString,
        context: RenderingContext
    ) {
        var offset = 0
        for run in attributed.runs {
            let runText = String(attributed[run.range].characters)
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
