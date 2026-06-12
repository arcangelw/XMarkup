import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 主题 DSL 组件协议
public protocol ThemeComponent: Sendable {
    func apply(to theme: inout MarkupTheme)
}

// MARK: - 基础字体

/// 设置基础字体
public struct BaseFontComponent: @unchecked Sendable, ThemeComponent {
    public let font: XMFont

    public init(_ font: XMFont) {
        self.font = font
    }

    public func apply(to theme: inout MarkupTheme) {
        theme.baseFont = font
    }
}

/// 便利函数：设置基础字体
public func BaseFont(_ font: XMFont) -> BaseFontComponent {
    BaseFontComponent(font)
}

/// 使用 Dynamic Type 文本样式设置基础字体
///
/// 字体大小随用户辅助功能设置自动调整。
///
/// ```swift
/// let theme = MarkupTheme {
///     BaseFont(textStyle: .body)
/// }
/// ```
public func BaseFont(textStyle: XMFontTextStyle) -> BaseFontComponent {
    #if canImport(UIKit)
    BaseFontComponent(UIFont.preferredFont(forTextStyle: textStyle))
    #elseif canImport(AppKit)
    BaseFontComponent(NSFont.preferredFont(forTextStyle: textStyle))
    #endif
}

// MARK: - 泛型块级/链接主题组件

/// 泛型主题组件 — 通过 KeyPath 绑定到 MarkupTheme 的对应字段
///
/// 统一替代 ParagraphThemeComponent / HeadingThemeComponent / ... / LinkThemeComponent
/// 8 个重复 struct，消除约 70 行重复代码。
public struct TypedThemeComponent<ThemeType>: @unchecked Sendable, ThemeComponent {
    let field: WritableKeyPath<MarkupTheme, ThemeType>
    let configure: @Sendable (inout ThemeType) -> Void

    public func apply(to theme: inout MarkupTheme) {
        configure(&theme[keyPath: field])
    }
}

// MARK: - 块级主题 DSL 入口（7 个）

/// 配置段落主题
public func Paragraph(_ configure: @escaping @Sendable (inout ParagraphTheme) -> Void) -> TypedThemeComponent<ParagraphTheme> {
    TypedThemeComponent(field: \.paragraph, configure: configure)
}

/// 配置标题主题
public func Heading(_ configure: @escaping @Sendable (inout HeadingTheme) -> Void) -> TypedThemeComponent<HeadingTheme> {
    TypedThemeComponent(field: \.heading, configure: configure)
}

/// 配置引用块主题
public func Blockquote(_ configure: @escaping @Sendable (inout BlockquoteTheme) -> Void) -> TypedThemeComponent<BlockquoteTheme> {
    TypedThemeComponent(field: \.blockquote, configure: configure)
}

/// 配置列表主题
public func List(_ configure: @escaping @Sendable (inout ListTheme) -> Void) -> TypedThemeComponent<ListTheme> {
    TypedThemeComponent(field: \.list, configure: configure)
}

/// 配置定义列表主题
public func DefinitionList(_ configure: @escaping @Sendable (inout DefinitionListTheme) -> Void) -> TypedThemeComponent<DefinitionListTheme> {
    TypedThemeComponent(field: \.definitionList, configure: configure)
}

/// 配置代码块主题
public func Preformatted(_ configure: @escaping @Sendable (inout PreformattedTheme) -> Void) -> TypedThemeComponent<PreformattedTheme> {
    TypedThemeComponent(field: \.preformatted, configure: configure)
}

/// 配置表格主题
public func Table(_ configure: @escaping @Sendable (inout TableTheme) -> Void) -> TypedThemeComponent<TableTheme> {
    TypedThemeComponent(field: \.table, configure: configure)
}

/// 配置水平线主题
public func HorizontalRule(_ configure: @escaping @Sendable (inout HorizontalRuleTheme) -> Void) -> TypedThemeComponent<HorizontalRuleTheme> {
    TypedThemeComponent(field: \.horizontalRule, configure: configure)
}

// MARK: - 内联主题 DSL 入口（9 个）

/// 配置粗体主题
public func Bold(_ configure: @escaping @Sendable (inout InlineTextTheme) -> Void) -> InlineThemeComponent {
    InlineThemeComponent(field: \.bold, configure: configure)
}

/// 配置斜体主题
public func Italic(_ configure: @escaping @Sendable (inout InlineTextTheme) -> Void) -> InlineThemeComponent {
    InlineThemeComponent(field: \.italic, configure: configure)
}

/// 配置下划线主题
public func Underline(_ configure: @escaping @Sendable (inout InlineTextTheme) -> Void) -> InlineThemeComponent {
    InlineThemeComponent(field: \.underline, configure: configure)
}

/// 配置删除线主题
public func Strikethrough(_ configure: @escaping @Sendable (inout InlineTextTheme) -> Void) -> InlineThemeComponent {
    InlineThemeComponent(field: \.strikethrough, configure: configure)
}

/// 配置行内代码主题
public func Code(_ configure: @escaping @Sendable (inout InlineTextTheme) -> Void) -> InlineThemeComponent {
    InlineThemeComponent(field: \.codeInline, configure: configure)
}

/// 配置高亮标记主题
public func Mark(_ configure: @escaping @Sendable (inout InlineTextTheme) -> Void) -> InlineThemeComponent {
    InlineThemeComponent(field: \.mark, configure: configure)
}

/// 配置下标主题
public func Subscript(_ configure: @escaping @Sendable (inout InlineTextTheme) -> Void) -> InlineThemeComponent {
    InlineThemeComponent(field: \.subscriptText, configure: configure)
}

/// 配置上标主题
public func Superscript(_ configure: @escaping @Sendable (inout InlineTextTheme) -> Void) -> InlineThemeComponent {
    InlineThemeComponent(field: \.superscript, configure: configure)
}

/// 配置链接主题
public func Link(_ configure: @escaping @Sendable (inout LinkTheme) -> Void) -> TypedThemeComponent<LinkTheme> {
    TypedThemeComponent(field: \.link, configure: configure)
}

/// 内联文本主题组件（通过 KeyPath 绑定到 MarkupTheme 的 InlineTextTheme 字段）
public struct InlineThemeComponent: @unchecked Sendable, ThemeComponent {
    let field: WritableKeyPath<MarkupTheme, InlineTextTheme>
    let configure: @Sendable (inout InlineTextTheme) -> Void

    public func apply(to theme: inout MarkupTheme) {
        configure(&theme[keyPath: field])
    }
}

// MARK: - 媒体策略

/// 配置媒体渲染策略
public func Media(_ strategy: MediaRenderingStrategy) -> MediaComponent {
    MediaComponent(strategy)
}

/// 媒体策略组件
public struct MediaComponent: @unchecked Sendable, ThemeComponent {
    public let strategy: MediaRenderingStrategy
    public init(_ strategy: MediaRenderingStrategy) {
        self.strategy = strategy
    }
    public func apply(to theme: inout MarkupTheme) {
        theme.media = strategy
    }
}
