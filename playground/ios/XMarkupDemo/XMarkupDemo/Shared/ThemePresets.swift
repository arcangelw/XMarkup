import Foundation
import XMarkup

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Spacing 示例专用主题

extension MarkupTheme {

    /// 紧凑排版：段前 2pt、段后 2pt
    static let spacingCompact: MarkupTheme = {
        MarkupTheme {
            Paragraph {
                $0.spacingBefore = 2
                $0.spacingAfter = 2
            }
        }
    }()

    /// 宽松排版 + 行距：段前 16pt、段后 16pt、行距 6pt
    static let spacingRelaxed: MarkupTheme = {
        MarkupTheme {
            Paragraph {
                $0.spacingBefore = 16
                $0.spacingAfter = 16
                $0.lineSpacing = 6
            }
        }
    }()

    /// 零间距：段前 0pt、段后 0pt
    static let spacingNone: MarkupTheme = {
        MarkupTheme {
            Paragraph {
                $0.spacingBefore = 0
                $0.spacingAfter = 0
            }
        }
    }()
}

// MARK: - 主题定制示例专用主题

extension MarkupTheme {

    /// 自定义代码样式：深色背景 + 绿色文字
    static let customCodeTheme: MarkupTheme = {
        MarkupTheme {
            BaseFont(.systemFont(ofSize: 16))
            Code {
                #if canImport(UIKit)
                $0.backgroundColor = UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)
                $0.textColor = UIColor(red: 0.2, green: 0.9, blue: 0.4, alpha: 1.0)
                #elseif canImport(AppKit)
                $0.backgroundColor = NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)
                $0.textColor = NSColor(red: 0.2, green: 0.9, blue: 0.4, alpha: 1.0)
                #endif
                $0.font = XMFont.monospacedSystemFont(ofSize: 16, weight: .medium)
            }
        }
    }()

    /// 自定义标记和链接样式：橙色高亮 + 紫色链接
    static let customMarkLinkTheme: MarkupTheme = {
        MarkupTheme {
            BaseFont(.systemFont(ofSize: 16))
            Mark {
                #if canImport(UIKit)
                $0.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.25)
                #elseif canImport(AppKit)
                $0.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.25)
                #endif
            }
            Link {
                #if canImport(UIKit)
                $0.textColor = UIColor.systemPurple
                #elseif canImport(AppKit)
                $0.textColor = NSColor.systemPurple
                #endif
            }
        }
    }()

    /// 标题级别覆盖：h1 红色、h2 蓝色、h3 绿色
    static let headingLevelOverrideTheme: MarkupTheme = {
        MarkupTheme {
            BaseFont(.systemFont(ofSize: 16))
            Heading {
                $0.scale = .default
                $0.bold = true
                #if canImport(UIKit)
                $0.h1 = .init(textColor: UIColor.systemRed)
                $0.h2 = .init(textColor: UIColor.systemBlue)
                $0.h3 = .init(textColor: UIColor.systemGreen)
                $0.h4 = .init(textColor: UIColor.systemOrange)
                $0.h5 = .init(textColor: UIColor.systemPurple)
                $0.h6 = .init(textColor: UIColor.systemTeal)
                #elseif canImport(AppKit)
                $0.h1 = .init(textColor: NSColor.systemRed)
                $0.h2 = .init(textColor: NSColor.systemBlue)
                $0.h3 = .init(textColor: NSColor.systemGreen)
                $0.h4 = .init(textColor: NSColor.systemOrange)
                $0.h5 = .init(textColor: NSColor.systemPurple)
                $0.h6 = .init(textColor: NSColor.systemTeal)
                #endif
            }
        }
    }()

    /// 动态 resolve：标题含 ⚠️ 自动变红
    static let dynamicResolveTheme: MarkupTheme = {
        MarkupTheme {
            BaseFont(.systemFont(ofSize: 16))
            Heading {
                $0.scale = .default
                $0.bold = true
                $0.resolve = { block, context, defaults in
                    if block.text.contains("⚠️") {
                        #if canImport(UIKit)
                        return defaults.with(\.textColor, UIColor.systemRed)
                        #elseif canImport(AppKit)
                        return defaults.with(\.textColor, NSColor.systemRed)
                        #endif
                    }
                    return nil
                }
            }
        }
    }()

    /// 自定义 preformatted 字体 + 引用块文字色
    static let customPreforBlockquoteTheme: MarkupTheme = {
        MarkupTheme {
            BaseFont(.systemFont(ofSize: 16))
            Preformatted {
                $0.font = XMFont.monospacedSystemFont(ofSize: 14, weight: .light)
                #if canImport(UIKit)
                $0.backgroundColor = UIColor.systemGray6
                #elseif canImport(AppKit)
                $0.backgroundColor = NSColor.systemGray.withAlphaComponent(0.1)
                #endif
            }
            Blockquote {
                #if canImport(UIKit)
                $0.textColor = UIColor.secondaryLabel
                #elseif canImport(AppKit)
                $0.textColor = NSColor.secondaryLabelColor
                #endif
                $0.indent = 20
            }
        }
    }()
}
