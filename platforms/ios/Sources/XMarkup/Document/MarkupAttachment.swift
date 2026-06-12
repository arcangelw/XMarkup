import Foundation

/// 平台无关的媒体附件描述
///
/// ```swift
/// let attachment = MarkupAttachment(
///     content: .image(src: "photo.jpg"),
///     suggestedSize: CGSize(width: 300, height: 200),
///     alignment: .center
/// )
/// ```
public struct MarkupAttachment: Sendable, Equatable {
    public let content: AttachmentContent
    public let suggestedSize: CGSize
    public let alignment: AttachmentAlignment
    public let altText: String?

    public init(
        content: AttachmentContent,
        suggestedSize: CGSize,
        alignment: AttachmentAlignment = .default,
        altText: String? = nil
    ) {
        self.content = content
        self.suggestedSize = suggestedSize
        self.alignment = alignment
        self.altText = altText
    }
}

/// 附件内容类型
public enum AttachmentContent: Sendable, Equatable {
    case image(src: String)                          // <img src="...">
    case video(src: String)                          // <video src="...">
    case audio(src: String)                          // <audio src="...">
    /// 第三方扩展入口，携带自定义类型和元数据
    case custom(type: String, metadata: [String: String])
}

/// 附件对齐方式
public enum AttachmentAlignment: String, Sendable, Equatable {
    case `default`  // 跟随文本方向
    case center     // 居中
    case leading    // 左对齐（LTR 环境下）
    case trailing   // 右对齐（LTR 环境下）
}
