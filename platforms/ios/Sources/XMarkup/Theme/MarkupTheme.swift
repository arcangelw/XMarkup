import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 纯值类型的样式主题
///
/// `Equatable` 比较 `baseFont`、`headingScale`、`paragraphSpacing`、`tagStyles` 四个样式配置字段。
/// `mediaStrategy` 包含闭包（`.imageProvider` / `.customAttachment`），不可比较，因此不参与判等。
/// 如需比较渲染策略是否相同，请单独检查 `mediaStrategy` 的 case。
public struct MarkupTheme: @unchecked Sendable, Equatable {
    /// 基础字体
    public var baseFont: XMFont
    /// 标题缩放系数
    public var headingScale: HeadingScale
    /// 段落排版配置（间距、行距）
    public var paragraphSpacing: ParagraphSpacing
    /// 标签样式映射
    public var tagStyles: [TagStyleKey: AttributeContainer]
    /// 块级排版配置（NSTextBlock / NSTextTable / NSTextList）
    public var blockStyles: [TagStyleKey: BlockStyleConfiguration]
    /// 媒体渲染策略（不参与 Equatable 比较，因包含闭包）
    public var mediaStrategy: MediaRenderingStrategy

    public init(
        baseFont: XMFont = XMFont.systemFont(ofSize: 16),
        headingScale: HeadingScale = .default,
        paragraphSpacing: ParagraphSpacing = .default,
        tagStyles: [TagStyleKey: AttributeContainer] = [:],
        blockStyles: [TagStyleKey: BlockStyleConfiguration] = [:],
        mediaStrategy: MediaRenderingStrategy = .placeholder
    ) {
        self.baseFont = baseFont
        self.headingScale = headingScale
        self.paragraphSpacing = paragraphSpacing
        self.tagStyles = tagStyles
        self.blockStyles = blockStyles
        self.mediaStrategy = mediaStrategy
    }

    /// Equatable 仅比较样式配置项，排除 mediaStrategy（闭包不可比较）
    public static func == (lhs: MarkupTheme, rhs: MarkupTheme) -> Bool {
        lhs.baseFont == rhs.baseFont
            && lhs.headingScale == rhs.headingScale
            && lhs.paragraphSpacing == rhs.paragraphSpacing
            && lhs.tagStyles == rhs.tagStyles
            && lhs.blockStyles == rhs.blockStyles
    }
}
