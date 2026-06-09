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

/// 基础字体组件
public struct BaseFont: @unchecked Sendable, ThemeComponent {
    public let font: XMFont

    public init(_ font: XMFont) {
        self.font = font
    }

    public func apply(to theme: inout MarkupTheme) {
        theme.baseFont = font
    }
}

/// 标题缩放组件
public struct HeadingScaleComponent: ThemeComponent {
    public let scale: HeadingScale

    public init(_ scale: HeadingScale) {
        self.scale = scale
    }

    public func apply(to theme: inout MarkupTheme) {
        theme.headingScale = scale
    }
}

/// 标签样式组件
public struct TagStyleComponent: ThemeComponent {
    public let key: TagStyleKey
    public let configure: @Sendable (inout AttributeContainer) -> Void

    public init(
        _ key: TagStyleKey,
        configure: @Sendable @escaping (inout AttributeContainer) -> Void
    ) {
        self.key = key
        self.configure = configure
    }

    public func apply(to theme: inout MarkupTheme) {
        var container = AttributeContainer()
        configure(&container)
        theme.tagStyles[key] = container
    }
}

/// 便利函数：创建 TagStyleComponent
public func Tag(
    _ key: TagStyleKey,
    configure: @Sendable @escaping (inout AttributeContainer) -> Void
) -> TagStyleComponent {
    TagStyleComponent(key, configure: configure)
}

/// 媒体策略组件
public struct MediaComponent: ThemeComponent {
    public let strategy: MediaRenderingStrategy

    public init(_ strategy: MediaRenderingStrategy) {
        self.strategy = strategy
    }

    public func apply(to theme: inout MarkupTheme) {
        theme.mediaStrategy = strategy
    }
}

/// 便利函数：创建 MediaComponent
public func Media(_ strategy: MediaRenderingStrategy) -> MediaComponent {
    MediaComponent(strategy)
}

/// 段落排版组件
public struct ParagraphSpacingComponent: ThemeComponent {
    public let spacing: ParagraphSpacing

    public init(_ spacing: ParagraphSpacing) {
        self.spacing = spacing
    }

    public func apply(to theme: inout MarkupTheme) {
        theme.paragraphSpacing = spacing
    }
}
