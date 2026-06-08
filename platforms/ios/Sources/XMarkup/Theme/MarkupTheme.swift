import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 纯值类型的样式主题
/// XMFont/NSFont 在 Apple 平台上实际是线程安全的 immutable 对象，
/// 但未标记 Sendable。使用 @unchecked Sendable 是安全的。
public struct MarkupTheme: @unchecked Sendable {
    /// 基础字体
    public var baseFont: XMFont
    /// 标题缩放系数
    public var headingScale: HeadingScale
    /// 标签样式映射
    public var tagStyles: [TagStyleKey: AttributeContainer]
    /// 媒体渲染策略
    public var mediaStrategy: MediaRenderingStrategy

    public init(
        baseFont: XMFont = XMFont.systemFont(ofSize: 16),
        headingScale: HeadingScale = .default,
        tagStyles: [TagStyleKey: AttributeContainer] = [:],
        mediaStrategy: MediaRenderingStrategy = .placeholder
    ) {
        self.baseFont = baseFont
        self.headingScale = headingScale
        self.tagStyles = tagStyles
        self.mediaStrategy = mediaStrategy
    }

    public static func == (lhs: MarkupTheme, rhs: MarkupTheme) -> Bool {
        lhs.baseFont == rhs.baseFont
            && lhs.headingScale == rhs.headingScale
            && lhs.tagStyles == rhs.tagStyles
    }
}
