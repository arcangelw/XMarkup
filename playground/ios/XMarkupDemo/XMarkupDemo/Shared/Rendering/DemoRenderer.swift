import Foundation
import XMarkup

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 平台无关渲染器 — HTML → NSAttributedString（设计规格 §5.1）
///
/// Demo 原生端统一渲染入口：
/// - 字号强制对齐 `DemoCanvasConfig.baseFont`（原生 = Web 字号，对比可信）
/// - 支持 themeOverride（单主题）与 themeVariants（多主题对比）
/// - 支持 appendHTML（追加渲染，验证追加段落拼接）
///
/// 迁移契约：此类型为平台无关层，iOS/macOS SwiftUI 视图均直接调用；
/// 未来 UIKit/AppKit 迁移时无需改动。
public enum DemoRenderer {

    /// 渲染单个示例为 NSAttributedString
    /// - Parameter theme: 外部主题覆盖（P2-1 主题切换 popover 用）；nil 时回退 example.themeOverride ?? .default
    public static func render(
        example: DemoExample,
        config: DemoCanvasConfig,
        theme override: MarkupTheme? = nil
    ) throws -> NSAttributedString {
        let document = try parse(example)
        // MarkupTheme 是 struct（值语义），baseFont 赋值不污染共享 .default
        var theme = override ?? example.themeOverride ?? .default
        theme.baseFont = config.baseFont
        // 对齐 Web a color #0066CC（Demo 原生=Web 对比基准）
        if theme.link.textColor == nil { theme.link.textColor = DemoPalette.linkColor }
        return document.render(theme: theme)
    }

    /// 渲染多个主题变体（主题对比示例用）
    public static func renderVariants(
        example: DemoExample,
        config: DemoCanvasConfig
    ) throws -> [NSAttributedString] {
        let document = try parse(example)
        let themes = example.themeVariants ?? [.default, .dark, .article]
        return themes.map { theme -> NSAttributedString in
            var t = theme
            t.baseFont = config.baseFont
            if t.link.textColor == nil { t.link.textColor = DemoPalette.linkColor }
            return document.render(theme: t)
        }
    }

    /// 解析示例 HTML → MarkupDocument（appendHTML 存在时追加拼接）
    public static func parse(
        _ example: DemoExample,
        parser: XMarkupParser? = nil
    ) throws -> MarkupDocument {
        let document = try MarkupDocument.from(html: example.html, parser: parser)
        if let second = example.appendHTML {
            return document.appending(try MarkupDocument.from(html: second, parser: parser))
        }
        return document
    }
}
