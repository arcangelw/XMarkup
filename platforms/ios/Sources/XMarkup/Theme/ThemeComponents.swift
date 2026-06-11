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

// MARK: - 块级主题 DSL 入口

/// 配置段落主题
public func Paragraph(_ configure: @escaping @Sendable (inout ParagraphTheme) -> Void) -> ParagraphThemeComponent {
    ParagraphThemeComponent(configure)
}

public struct ParagraphThemeComponent: @unchecked Sendable, ThemeComponent {
    private let configure: @Sendable (inout ParagraphTheme) -> Void
    init(_ configure: @escaping @Sendable (inout ParagraphTheme) -> Void) {
        self.configure = configure
    }
    public func apply(to theme: inout MarkupTheme) {
        configure(&theme.paragraph)
    }
}

/// 配置标题主题
public func Heading(_ configure: @escaping @Sendable (inout HeadingTheme) -> Void) -> HeadingThemeComponent {
    HeadingThemeComponent(configure)
}

public struct HeadingThemeComponent: @unchecked Sendable, ThemeComponent {
    private let configure: @Sendable (inout HeadingTheme) -> Void
    init(_ configure: @escaping @Sendable (inout HeadingTheme) -> Void) {
        self.configure = configure
    }
    public func apply(to theme: inout MarkupTheme) {
        configure(&theme.heading)
    }
}

/// 配置引用块主题
public func Blockquote(_ configure: @escaping @Sendable (inout BlockquoteTheme) -> Void) -> BlockquoteThemeComponent {
    BlockquoteThemeComponent(configure)
}

public struct BlockquoteThemeComponent: @unchecked Sendable, ThemeComponent {
    private let configure: @Sendable (inout BlockquoteTheme) -> Void
    init(_ configure: @escaping @Sendable (inout BlockquoteTheme) -> Void) {
        self.configure = configure
    }
    public func apply(to theme: inout MarkupTheme) {
        configure(&theme.blockquote)
    }
}

/// 配置列表主题
public func List(_ configure: @escaping @Sendable (inout ListTheme) -> Void) -> ListThemeComponent {
    ListThemeComponent(configure)
}

public struct ListThemeComponent: @unchecked Sendable, ThemeComponent {
    private let configure: @Sendable (inout ListTheme) -> Void
    init(_ configure: @escaping @Sendable (inout ListTheme) -> Void) {
        self.configure = configure
    }
    public func apply(to theme: inout MarkupTheme) {
        configure(&theme.list)
    }
}

/// 配置代码块主题
public func Preformatted(_ configure: @escaping @Sendable (inout PreformattedTheme) -> Void) -> PreformattedThemeComponent {
    PreformattedThemeComponent(configure)
}

public struct PreformattedThemeComponent: @unchecked Sendable, ThemeComponent {
    private let configure: @Sendable (inout PreformattedTheme) -> Void
    init(_ configure: @escaping @Sendable (inout PreformattedTheme) -> Void) {
        self.configure = configure
    }
    public func apply(to theme: inout MarkupTheme) {
        configure(&theme.preformatted)
    }
}

/// 配置表格主题
public func Table(_ configure: @escaping @Sendable (inout TableTheme) -> Void) -> TableThemeComponent {
    TableThemeComponent(configure)
}

public struct TableThemeComponent: @unchecked Sendable, ThemeComponent {
    private let configure: @Sendable (inout TableTheme) -> Void
    init(_ configure: @escaping @Sendable (inout TableTheme) -> Void) {
        self.configure = configure
    }
    public func apply(to theme: inout MarkupTheme) {
        configure(&theme.table)
    }
}

/// 配置水平线主题
public func HorizontalRule(_ configure: @escaping @Sendable (inout HorizontalRuleTheme) -> Void) -> HorizontalRuleThemeComponent {
    HorizontalRuleThemeComponent(configure)
}

public struct HorizontalRuleThemeComponent: @unchecked Sendable, ThemeComponent {
    private let configure: @Sendable (inout HorizontalRuleTheme) -> Void
    init(_ configure: @escaping @Sendable (inout HorizontalRuleTheme) -> Void) {
        self.configure = configure
    }
    public func apply(to theme: inout MarkupTheme) {
        configure(&theme.horizontalRule)
    }
}

// MARK: - 内联主题 DSL 入口

/// 配置粗体主题
public func Bold(_ configure: @escaping @Sendable (inout InlineTextTheme) -> Void) -> InlineThemeComponent {
    InlineThemeComponent(field: \MarkupTheme.bold, configure: configure)
}

/// 配置斜体主题
public func Italic(_ configure: @escaping @Sendable (inout InlineTextTheme) -> Void) -> InlineThemeComponent {
    InlineThemeComponent(field: \MarkupTheme.italic, configure: configure)
}

/// 配置下划线主题
public func Underline(_ configure: @escaping @Sendable (inout InlineTextTheme) -> Void) -> InlineThemeComponent {
    InlineThemeComponent(field: \MarkupTheme.underline, configure: configure)
}

/// 配置删除线主题
public func Strikethrough(_ configure: @escaping @Sendable (inout InlineTextTheme) -> Void) -> InlineThemeComponent {
    InlineThemeComponent(field: \MarkupTheme.strikethrough, configure: configure)
}

/// 配置行内代码主题
public func Code(_ configure: @escaping @Sendable (inout InlineTextTheme) -> Void) -> InlineThemeComponent {
    InlineThemeComponent(field: \MarkupTheme.codeInline, configure: configure)
}

/// 配置高亮标记主题
public func Mark(_ configure: @escaping @Sendable (inout InlineTextTheme) -> Void) -> InlineThemeComponent {
    InlineThemeComponent(field: \MarkupTheme.mark, configure: configure)
}

/// 配置下标主题
public func Subscript(_ configure: @escaping @Sendable (inout InlineTextTheme) -> Void) -> InlineThemeComponent {
    InlineThemeComponent(field: \MarkupTheme.subscriptText, configure: configure)
}

/// 配置上标主题
public func Superscript(_ configure: @escaping @Sendable (inout InlineTextTheme) -> Void) -> InlineThemeComponent {
    InlineThemeComponent(field: \MarkupTheme.superscript, configure: configure)
}

/// 内联文本主题组件（通过 KeyPath 绑定到 MarkupTheme 的对应字段）
public struct InlineThemeComponent: @unchecked Sendable, ThemeComponent {
    private let field: WritableKeyPath<MarkupTheme, InlineTextTheme>
    private let configure: @Sendable (inout InlineTextTheme) -> Void

    init(field: WritableKeyPath<MarkupTheme, InlineTextTheme>,
         configure: @escaping @Sendable (inout InlineTextTheme) -> Void) {
        self.field = field
        self.configure = configure
    }

    public func apply(to theme: inout MarkupTheme) {
        configure(&theme[keyPath: field])
    }
}

/// 配置链接主题
public func Link(_ configure: @escaping @Sendable (inout LinkTheme) -> Void) -> LinkThemeComponent {
    LinkThemeComponent(configure)
}

/// 链接主题组件
public struct LinkThemeComponent: @unchecked Sendable, ThemeComponent {
    private let configure: @Sendable (inout LinkTheme) -> Void
    init(_ configure: @escaping @Sendable (inout LinkTheme) -> Void) {
        self.configure = configure
    }
    public func apply(to theme: inout MarkupTheme) {
        configure(&theme.link)
    }
}

// MARK: - 媒体策略

/// 配置媒体渲染策略
public func Media(_ strategy: MediaRenderingStrategy) -> MediaComponent {
    MediaComponent(strategy)
}

public struct MediaComponent: @unchecked Sendable, ThemeComponent {
    public let strategy: MediaRenderingStrategy
    public init(_ strategy: MediaRenderingStrategy) {
        self.strategy = strategy
    }
    public func apply(to theme: inout MarkupTheme) {
        theme.media = strategy
    }
}
