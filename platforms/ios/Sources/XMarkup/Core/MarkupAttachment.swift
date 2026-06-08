import Foundation

/// 平台无关的媒体附件描述
public struct MarkupAttachment: Sendable, Equatable {
    public let content: AttachmentContent
    public let suggestedSize: CGSize
    public let alignment: AttachmentAlignment

    public init(
        content: AttachmentContent,
        suggestedSize: CGSize,
        alignment: AttachmentAlignment = .default
    ) {
        self.content = content
        self.suggestedSize = suggestedSize
        self.alignment = alignment
    }
}

/// 附件内容类型
public enum AttachmentContent: Sendable, Equatable {
    case image(src: String)
    case video(src: String)
    case audio(src: String)
    /// 第三方扩展入口
    case custom(type: String, metadata: [String: String])
}

/// 附件对齐方式
public enum AttachmentAlignment: String, Sendable, Equatable {
    case `default`
    case center
    case leading
    case trailing
}
