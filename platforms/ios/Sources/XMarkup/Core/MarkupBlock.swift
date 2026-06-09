import Foundation

/// 段落级块（h1-h6, p, blockquote, pre, li, hr, div 等）
///
/// 每个 `MarkupBlock` 对应 HTML 中的一个块级元素，包含纯文本、
/// 内联样式区间和可选的媒体附件。
///
/// ```swift
/// let block = doc.blocks[0]
/// print(block.kind)        // .paragraph
/// print(block.text)        // "Hello world"
/// print(block.inlines)     // [MarkupInline(range: (6,5), kind: .bold)]
/// print(block.attachment)  // nil（非媒体块）
/// ```
public struct MarkupBlock: Sendable, Equatable {
    public let kind: BlockKind
    /// 该段落的纯文本
    public let text: String
    /// 内联样式区间（bold/italic/link/code/mark 等）
    public let inlines: [MarkupInline]
    /// 媒体附件（image/video/audio/custom），非媒体块为 nil
    public let attachment: MarkupAttachment?

    public init(
        kind: BlockKind,
        text: String,
        inlines: [MarkupInline],
        attachment: MarkupAttachment?
    ) {
        self.kind = kind
        self.text = text
        self.inlines = inlines
        self.attachment = attachment
    }
}
