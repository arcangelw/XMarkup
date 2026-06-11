import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension MarkupTheme {

    /// 通用主题
    public static let `default`: MarkupTheme = {
        MarkupTheme {
            BaseFont(.systemFont(ofSize: 16))
            Heading {
                $0.scale = .default
                $0.bold = true
            }
            Code { theme in
                theme.font = XMFont.monospacedSystemFont(ofSize: 16, weight: .regular)
                #if canImport(UIKit)
                theme.backgroundColor = .systemGray6
                #elseif canImport(AppKit)
                theme.backgroundColor = .systemGray.withAlphaComponent(0.15)
                #endif
            }
            Mark { theme in
                #if canImport(UIKit)
                theme.backgroundColor = .systemYellow.withAlphaComponent(0.3)
                #elseif canImport(AppKit)
                theme.backgroundColor = .systemYellow.withAlphaComponent(0.3)
                #endif
            }
        }
    }()

    /// 暗色模式主题
    ///
    /// - Note: 当前为静态颜色占位实现。完整的暗色适配应使用
    ///         `UIColor { traitCollection in ... }` 动态颜色，
    ///         根据用户外观偏好自动切换，待 P2 实现。
    public static let dark: MarkupTheme = {
        MarkupTheme {
            BaseFont(.systemFont(ofSize: 16))
            Heading {
                $0.scale = .default
                $0.bold = true
            }
            Code { theme in
                theme.font = XMFont.monospacedSystemFont(ofSize: 16, weight: .regular)
                #if canImport(UIKit)
                theme.backgroundColor = .systemGray
                #elseif canImport(AppKit)
                theme.backgroundColor = .systemGray.withAlphaComponent(0.3)
                #endif
            }
            Mark { theme in
                #if canImport(UIKit)
                theme.backgroundColor = .systemOrange.withAlphaComponent(0.3)
                #elseif canImport(AppKit)
                theme.backgroundColor = .systemOrange.withAlphaComponent(0.3)
                #endif
            }
        }
    }()

    /// 聊天气泡主题
    public static let chat: MarkupTheme = {
        MarkupTheme(baseFont: XMFont.systemFont(ofSize: 14))
    }()

    /// 文章阅读主题
    public static let article: MarkupTheme = {
        MarkupTheme {
            BaseFont(.systemFont(ofSize: 17))
            Heading {
                $0.scale = .default
                $0.bold = true
            }
            Blockquote {
                #if canImport(UIKit)
                $0.textColor = .secondaryLabel
                #elseif canImport(AppKit)
                $0.textColor = .secondaryLabelColor
                #endif
            }
            Code { theme in
                theme.font = XMFont.monospacedSystemFont(ofSize: 17, weight: .regular)
                #if canImport(UIKit)
                theme.backgroundColor = .systemGray6
                #elseif canImport(AppKit)
                theme.backgroundColor = .textBackgroundColor
                #endif
            }
        }
    }()
}
