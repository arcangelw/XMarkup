import Foundation

/// 段落级块（h1-h6, p, blockquote, pre, li, hr, div 等）
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
