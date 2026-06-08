import Foundation

@resultBuilder
public enum MarkupThemeBuilder {
    public static func buildBlock(_ components: ThemeComponent...) -> [ThemeComponent] {
        Array(components)
    }
}

extension MarkupTheme {
    /// 使用 Result Builder DSL 构建主题
    public init(@MarkupThemeBuilder builder: () -> [ThemeComponent]) {
        self.init()
        var theme = MarkupTheme()
        for component in builder() {
            component.apply(to: &theme)
        }
        self = theme
    }
}
