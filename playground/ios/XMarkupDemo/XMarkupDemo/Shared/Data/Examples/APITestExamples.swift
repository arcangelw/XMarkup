import Foundation
import XMarkup

/// API 测试族 — 暂时下线（visibility = .hidden），数据保留便于后期恢复（设计规格 §10）
enum APITestExamples {
    static let all: [DemoExample] = [
        DemoExample(id: "api-append", title: "appending() 拼接", summary: "两段独立 HTML 分别解析后 append",
            html: """
            <h3>第一段：核心特性</h3>
            <p>XMarkup 支持 <b>粗体</b>、<i>斜体</i>、<u>下划线</u> 等基础格式。</p>
            <p>还支持 <code>行内代码</code> 和 <a href="https://example.com">超链接</a>。</p>
            """,
            family: .showcase, tier: .basic,
            visibility: .hidden,
            appendHTML: """
            <h3>第二段：高级特性</h3>
            <p>支持 <span style="color:#FF0000">彩色文字</span> 和 <span style="background-color:#FFFF00">高亮背景</span>。</p>
            <p>支持各级标题 <b>H1~H6</b> 和 <mark>标记高亮</mark>。</p>
            """),
        DemoExample(id: "api-themes", title: "多主题对比", summary: "同一 HTML 在 default/dark/article 三主题下渲染",
            html: """
            <h2>XMarkup 渲染引擎</h2>
            <p>XMarkup 是一个高性能的 <b>HTML 富文本解析引擎</b>，支持多种格式和样式。</p>
            <p>它使用 <code>render(theme:)</code> 方法将解析结果转换为 <code>AttributedString</code>。</p>
            <p>通过不同的 <a href="https://example.com/themes">MarkupTheme</a> 配置，同一内容可以有截然不同的呈现效果。</p>
            <blockquote>试试切换不同的主题，感受排版的差异。</blockquote>
            """,
            family: .theme, tier: .basic,
            visibility: .hidden,
            themeVariants: [.default, .dark, .article]),
    ]
}
