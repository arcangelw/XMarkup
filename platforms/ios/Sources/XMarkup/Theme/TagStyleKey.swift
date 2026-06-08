import Foundation

/// 主题配置 key（用于 tagStyles 字典）
public enum TagStyleKey: String, Sendable, Equatable, Hashable, CaseIterable {
    case bold, italic, underline, strikethrough, code, mark
    case link, heading, paragraph, blockquote, preformatted
    case listItem, division, horizontalRule
    case image, video, audio
}
