import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension MarkupTheme {

    /// 通用主题
    public static let `default`: MarkupTheme = {
        var theme = MarkupTheme()
        #if canImport(UIKit)
        var markStyle = AttributeContainer()
        markStyle.uiKit.backgroundColor = .systemYellow.withAlphaComponent(0.3)
        theme.tagStyles[.mark] = markStyle

        var codeStyle = AttributeContainer()
        codeStyle.uiKit.backgroundColor = .systemGray6
        codeStyle.uiKit.font = .monospacedSystemFont(ofSize: theme.baseFont.pointSize, weight: .regular)
        theme.tagStyles[.code] = codeStyle
        #elseif canImport(AppKit)
        var markStyle = AttributeContainer()
        markStyle.appKit.backgroundColor = .systemYellow.withAlphaComponent(0.3)
        theme.tagStyles[.mark] = markStyle

        var codeStyle = AttributeContainer()
        codeStyle.appKit.backgroundColor = .systemGray.withAlphaComponent(0.15)
        codeStyle.appKit.font = .monospacedSystemFont(ofSize: theme.baseFont.pointSize, weight: .regular)
        theme.tagStyles[.code] = codeStyle
        #endif
        return theme
    }()

    /// 暗色模式主题
    ///
    /// - Note: 当前为静态颜色占位实现。完整的暗色适配应使用
    ///         `UIColor { traitCollection in ... }` 动态颜色，
    ///         根据用户外观偏好自动切换，待 P2 实现。
    public static let dark: MarkupTheme = {
        var theme = MarkupTheme()
        #if canImport(UIKit)
        var markStyle = AttributeContainer()
        markStyle.uiKit.backgroundColor = .systemOrange.withAlphaComponent(0.3)
        theme.tagStyles[.mark] = markStyle

        var codeStyle = AttributeContainer()
        codeStyle.uiKit.backgroundColor = .systemGray
        codeStyle.uiKit.font = .monospacedSystemFont(ofSize: theme.baseFont.pointSize, weight: .regular)
        theme.tagStyles[.code] = codeStyle
        #elseif canImport(AppKit)
        var markStyle = AttributeContainer()
        markStyle.appKit.backgroundColor = .systemOrange.withAlphaComponent(0.3)
        theme.tagStyles[.mark] = markStyle

        var codeStyle = AttributeContainer()
        codeStyle.appKit.backgroundColor = .systemGray.withAlphaComponent(0.3)
        codeStyle.appKit.font = .monospacedSystemFont(ofSize: theme.baseFont.pointSize, weight: .regular)
        theme.tagStyles[.code] = codeStyle
        #endif
        return theme
    }()

    /// 聊天气泡主题
    public static let chat: MarkupTheme = {
        var theme = MarkupTheme(baseFont: XMFont.systemFont(ofSize: 14))
        #if canImport(UIKit)
        var linkStyle = AttributeContainer()
        linkStyle.uiKit.foregroundColor = .systemBlue
        theme.tagStyles[.link] = linkStyle
        #elseif canImport(AppKit)
        var linkStyle = AttributeContainer()
        linkStyle.appKit.foregroundColor = .linkColor
        theme.tagStyles[.link] = linkStyle
        #endif
        return theme
    }()

    /// 文章阅读主题
    public static let article: MarkupTheme = {
        var theme = MarkupTheme(baseFont: XMFont.systemFont(ofSize: 17))
        #if canImport(UIKit)
        var blockquoteStyle = AttributeContainer()
        blockquoteStyle.uiKit.foregroundColor = .secondaryLabel
        theme.tagStyles[.blockquote] = blockquoteStyle

        var codeStyle = AttributeContainer()
        codeStyle.uiKit.backgroundColor = .systemGray6
        codeStyle.uiKit.font = .monospacedSystemFont(ofSize: theme.baseFont.pointSize, weight: .regular)
        theme.tagStyles[.code] = codeStyle
        #elseif canImport(AppKit)
        var blockquoteStyle = AttributeContainer()
        blockquoteStyle.appKit.foregroundColor = .secondaryLabelColor
        theme.tagStyles[.blockquote] = blockquoteStyle

        var codeStyle = AttributeContainer()
        codeStyle.appKit.backgroundColor = .textBackgroundColor
        codeStyle.appKit.font = .monospacedSystemFont(ofSize: theme.baseFont.pointSize, weight: .regular)
        theme.tagStyles[.code] = codeStyle
        #endif
        return theme
    }()
}
