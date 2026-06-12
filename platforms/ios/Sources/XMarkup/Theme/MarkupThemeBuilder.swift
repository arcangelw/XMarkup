import Foundation

@resultBuilder
public enum MarkupThemeBuilder {
    public static func buildBlock(_ components: ThemeComponent...) -> [ThemeComponent] {
        Array(components)
    }
}

extension MarkupTheme {
    /// 使用 Result Builder DSL 构建主题
    ///
    /// ```swift
    /// let theme = MarkupTheme {
    ///     BaseFont(.systemFont(ofSize: 17))
    ///     Heading {
    ///         $0.scale = HeadingScale(h1: 2.5)
    ///         $0.bold = true
    ///     }
    ///     Paragraph {
    ///         $0.spacingBefore = 12
    ///         $0.spacingAfter = 12
    ///     }
    ///     Code {
    ///         $0.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
    ///         $0.backgroundColor = .systemGray6
    ///     }
    ///     Link {
    ///         $0.textColor = .systemBlue
    ///     }
    ///     Media(.placeholder)
    /// }
    /// ```
    public init(@MarkupThemeBuilder builder: () -> [ThemeComponent]) {
        var theme = MarkupTheme()
        for component in builder() {
            component.apply(to: &theme)
        }
        self = theme
    }
}
