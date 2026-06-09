import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 纯值类型的样式主题
///
/// `Equatable` 仅比较 `baseFont`、`headingScale`、`tagStyles` 三个样式配置字段。
/// `mediaStrategy` 包含闭包（`.imageProvider` / `.customAttachment`），不可比较，因此不参与判等。
/// 如需比较渲染策略是否相同，请单独检查 `mediaStrategy` 的 case。
public struct MarkupTheme: @unchecked Sendable, Equatable {
    /// 基础字体
    public var baseFont: XMFont
    /// 标题缩放系数
    public var headingScale: HeadingScale
    /// 标签样式映射
    public var tagStyles: [TagStyleKey: AttributeContainer]
    /// 媒体渲染策略（不参与 Equatable 比较，因包含闭包）
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

    /// Equatable 仅比较样式配置项，排除 mediaStrategy（闭包不可比较）
    public static func == (lhs: MarkupTheme, rhs: MarkupTheme) -> Bool {
        lhs.baseFont == rhs.baseFont
            && lhs.headingScale == rhs.headingScale
            && lhs.tagStyles == rhs.tagStyles
    }
}
