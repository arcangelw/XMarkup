import Foundation

/// WebView 共享渲染（设计规格 §5.1）— 接 DemoCanvasConfig 注入 CSS
///
/// body CSS 由 `DemoCanvasConfig.cssString()` 提供，与原生端 textContainerInset 同源，
/// 保证两端 padding/行高/字号一致，对比时差异 = 渲染器真实行为差异。
enum WebViewRenderer {

    /// 注入 config CSS 的完整 HTML 文档（可直传 WKWebView.loadHTMLString）
    static func styledHTML(from html: String, config: DemoCanvasConfig) -> String {
        """
        <!DOCTYPE html><html><head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        \(config.cssString())
        img { max-width: 100%; height: auto; }
        a { color: #0066CC; text-decoration: none; }
        a:hover { text-decoration: underline; }
        code { background: #f5f5f5; padding: 2px 4px; border-radius: 3px; font-family: ui-monospace, monospace; }
        pre { background: #f5f5f5; padding: 12px; border-radius: 6px; overflow-x: auto; }
        blockquote { border-left: 4px solid #ddd; margin: 0; padding: 8px 16px; color: #666; }
        h1,h2,h3,h4,h5,h6 { margin-top: 1em; margin-bottom: 0.5em; }
        p { margin-top: 0; margin-bottom: 0.5em; }
        table { border-collapse: collapse; margin: 0.5em 0; }
        th, td { border: 1px solid #ddd; padding: 6px 10px; text-align: left; }
        th { background: #f5f5f5; }
        </style></head><body>\(html)</body></html>
        """
    }
}
