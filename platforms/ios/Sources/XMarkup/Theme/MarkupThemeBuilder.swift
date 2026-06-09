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
    ///     HeadingScaleComponent(HeadingScale(h1: 2.5))
    ///     ParagraphSpacingComponent(ParagraphSpacing(spacingBefore: 12, spacingAfter: 12))
    ///     Tag(.code) { $0.uiKit.backgroundColor = .systemGray6 }
    ///     Tag(.link) { $0.uiKit.foregroundColor = .systemBlue }
    /// }
    /// ```
    public init(@MarkupThemeBuilder builder: () -> [ThemeComponent]) {
        self.init()
        var theme = MarkupTheme()
        for component in builder() {
            component.apply(to: &theme)
        }
        self = theme
    }
}
