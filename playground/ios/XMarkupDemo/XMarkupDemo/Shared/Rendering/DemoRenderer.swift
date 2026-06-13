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
/// - 链接色对齐 Web #0066CC（DemoPalette.linkColor）
/// - 支持 themeOverride（单主题）与 themeVariants（多主题对比）
/// - 支持 appendHTML（追加渲染，验证追加段落拼接）
///
/// 提供 document 版（render(document:)）与 example 版（render(example:)）：
/// 上层（CompareDetailView）可先 parse 拿 document（含 source 供调试），再 render(document:)，避免重复 parse。
public enum DemoRenderer {

    /// 渲染（接已 parse 的 document，避免重复解析；供上层复用 document.source）
    public static func render(
        document: MarkupDocument,
        config: DemoCanvasConfig,
        theme override: MarkupTheme? = nil
    ) -> NSAttributedString {
        var theme = override ?? .default
        theme.baseFont = config.baseFont
        // 对齐 Web a color #0066CC（Demo 原生=Web 对比基准）
        if theme.link.textColor == nil { theme.link.textColor = DemoPalette.linkColor }
        return document.render(theme: theme)
    }

    /// 渲染多主题变体（接 document）
    public static func renderVariants(
        document: MarkupDocument,
        config: DemoCanvasConfig,
        themes: [MarkupTheme]
    ) -> [NSAttributedString] {
        themes.map { theme -> NSAttributedString in
            var t = theme
            t.baseFont = config.baseFont
            if t.link.textColor == nil { t.link.textColor = DemoPalette.linkColor }
            return document.render(theme: t)
        }
    }

    /// 渲染（接 example，内部 parse；themeOverride 优先 example.themeOverride）
    public static func render(
        example: DemoExample,
        config: DemoCanvasConfig,
        theme override: MarkupTheme? = nil
    ) throws -> NSAttributedString {
        let document = try parse(example)
        return render(document: document, config: config, theme: override ?? example.themeOverride)
    }

    /// 渲染多主题变体（接 example）
    public static func renderVariants(
        example: DemoExample,
        config: DemoCanvasConfig
    ) throws -> [NSAttributedString] {
        let document = try parse(example)
        let themes = example.themeVariants ?? [.default, .dark, .article]
        return renderVariants(document: document, config: config, themes: themes)
    }

    /// 解析示例 HTML → MarkupDocument（appendHTML 存在时追加拼接，source 合并保留）
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
