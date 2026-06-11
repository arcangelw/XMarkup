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
            Code {
                // font 不硬编码 — 由 inline renderer 从当前 run 的字号动态派生等宽字体，
                // 确保 code 在 heading 等场景下正确继承块级字号
                #if canImport(UIKit)
                $0.backgroundColor = .systemGray6
                #elseif canImport(AppKit)
                $0.backgroundColor = .systemGray.withAlphaComponent(0.15)
                #endif
            }
            Mark {
                #if canImport(UIKit)
                $0.backgroundColor = .systemYellow.withAlphaComponent(0.3)
                #elseif canImport(AppKit)
                $0.backgroundColor = .systemYellow.withAlphaComponent(0.3)
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
            Code {
                #if canImport(UIKit)
                $0.backgroundColor = .systemGray
                #elseif canImport(AppKit)
                $0.backgroundColor = .systemGray.withAlphaComponent(0.3)
                #endif
            }
            Mark {
                #if canImport(UIKit)
                $0.backgroundColor = .systemOrange.withAlphaComponent(0.3)
                #elseif canImport(AppKit)
                $0.backgroundColor = .systemOrange.withAlphaComponent(0.3)
                #endif
            }
        }
    }()

    /// 聊天气泡主题
    public static let chat: MarkupTheme = {
        MarkupTheme {
            BaseFont(XMFont.systemFont(ofSize: 14))
            Link {
                #if canImport(UIKit)
                $0.textColor = .systemBlue
                #elseif canImport(AppKit)
                $0.textColor = .linkColor
                #endif
            }
        }
    }()

    /// 文章阅读主题
    public static let article: MarkupTheme = {
        MarkupTheme {
            BaseFont(.systemFont(ofSize: 17))
            Heading {
                $0.scale = .default
                $0.bold = true
            }
            Paragraph {
                $0.spacingBefore = 12
                $0.spacingAfter = 12
                $0.lineSpacing = 4
            }
            Blockquote {
                #if canImport(UIKit)
                $0.textColor = .secondaryLabel
                #elseif canImport(AppKit)
                $0.textColor = .secondaryLabelColor
                #endif
            }
            Code {
                #if canImport(UIKit)
                $0.backgroundColor = .systemGray6
                #elseif canImport(AppKit)
                $0.backgroundColor = .textBackgroundColor
                #endif
            }
        }
    }()
}
