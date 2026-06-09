import Foundation

/// WebView 共享渲染工具
///
/// 将原始 HTML 包装为完整 HTML 文档，注入基础 CSS 确保可读性。
/// 三端 WebView 控制器统一使用此方法生成加载内容。
enum WebViewRenderer {

    /// 注入基础 CSS 的 HTML 文档
    ///
    /// - Parameter html: 原始 HTML 片段
    /// - Returns: 可直接传给 WKWebView.loadHTMLString 的完整 HTML
    static func styledHTML(from html: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            body {
                font-family: -apple-system, sans-serif;
                padding: 16px;
                margin: 0;
                line-height: 1.6;
                -webkit-text-size-adjust: 100%;
            }
            img { max-width: 100%; height: auto; }
            a { color: #0066CC; text-decoration: none; }
            a:hover { text-decoration: underline; }
            code { background: #f5f5f5; padding: 2px 4px; border-radius: 3px; font-family: monospace; }
            pre { background: #f5f5f5; padding: 12px; border-radius: 6px; overflow-x: auto; }
            blockquote { border-left: 4px solid #ddd; margin: 0; padding: 8px 16px; color: #666; }
            h1, h2, h3, h4, h5, h6 { margin-top: 1em; margin-bottom: 0.5em; }
            p { margin-top: 0; margin-bottom: 0.5em; }
        </style>
        </head>
        <body>
        \(html)
        </body>
        </html>
        """
    }
}
