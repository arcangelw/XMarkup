import Foundation
import XMarkup

/// 主题对比族 — customTheme 驱动 + 段落间距配置 + 多主题并排（themeVariants）
enum ThemeExamples {
    static let all: [DemoExample] = [
        // MARK: 段落排版（spacing 系列）
        DemoExample(id: "spacing-default", title: "默认间距", summary: "ParagraphSpacing(8, 8, 0)",
            html: """
            <p>第一段：使用默认段落间距（段前 8pt、段后 8pt、行距 0）。</p>
            <p>第二段：注意观察段落之间的间距。合理的段落间距能显著提升阅读体验。</p>
            <p>第三段：每个 <code>&lt;p&gt;</code> 标签对应一个独立的段落 block。</p>
            <p>第四段：通过对比其他间距示例，可以直观感受不同配置的效果。</p>
            <h3>标题也参与段落间距</h3>
            <p>标题下方的第五段文字。</p>
            """,
            family: .theme, tier: .basic, themeOverride: .default),
        DemoExample(id: "spacing-compact", title: "紧凑排版", summary: "ParagraphSpacing(2, 2, 0)",
            html: """
            <p>第一段：使用紧凑段落间距（段前 2pt、段后 2pt、行距 0）。</p>
            <p>第二段：紧凑排版适合信息密度高的场景，如列表、数据展示。</p>
            <p>第三段：段落之间几乎没有额外空白。</p>
            <p>第四段：紧凑排版可让更多内容在有限空间内展示。</p>
            <h3>紧凑标题</h3>
            <p>标题下方的第五段文字。</p>
            """,
            family: .theme, tier: .basic, themeOverride: .spacingCompact),
        DemoExample(id: "spacing-relaxed", title: "宽松排版 + 行距", summary: "ParagraphSpacing(16, 16, 6)",
            html: """
            <p>第一段：使用宽松段落间距（段前 16pt、段后 16pt、行距 6pt）。</p>
            <p>第二段：宽松排版适合长文阅读场景，给眼睛更多呼吸空间。</p>
            <p>第三段：额外的行间距让每行文字更加清晰可辨。</p>
            <p>第四段：适合文章、书籍等需要舒适阅读体验的场景。</p>
            <h3>宽松标题</h3>
            <p>标题下方的第五段文字。</p>
            """,
            family: .theme, tier: .basic, themeOverride: .spacingRelaxed),
        DemoExample(id: "spacing-none", title: "零间距", summary: "ParagraphSpacing(0, 0, 0)",
            html: """
            <p>第一段：使用零间距（段前 0pt、段后 0pt、行距 0pt）。</p>
            <p>第二段：段落之间没有任何额外间距，紧密相连。</p>
            <p>第三段：适用于需要精确控制排版的特殊场景。</p>
            <p>第四段：零间距让所有内容挤在一起。</p>
            <h3>零间距标题</h3>
            <p>标题下方的第五段文字。</p>
            """,
            family: .theme, tier: .basic, themeOverride: .spacingNone),
        // MARK: 主题定制
        DemoExample(id: "theme-dark", title: "深色主题", summary: ".dark 预设主题，适合暗色模式",
            html: """
            <h2>深色主题演示</h2>
            <p>这是使用 <code>.dark</code> 预设主题渲染的效果。深色主题对 <mark>高亮标记</mark> 和 <code>行内代码</code> 使用了不同的配色方案。</p>
            <blockquote>引用块在深色主题下也有独特的视觉效果。</blockquote>
            <p>对比 WebView 标签的浏览器渲染差异。</p>
            """,
            family: .theme, tier: .nested, themeOverride: .dark),
        DemoExample(id: "theme-custom-code", title: "自定义代码样式", summary: "深色背景 + 绿色文字 + 等宽中粗体",
            html: """
            <h3>自定义代码主题</h3>
            <p>XMarkup 的 typed theme 系统允许你精确控制每种内联元素的样式。</p>
            <p>使用 <code>Code { $0.backgroundColor = ... }</code> DSL 配置代码样式：</p>
            <ul>
            <li>背景色：<code>深色灰底</code></li>
            <li>文字色：<code>绿色文字</code></li>
            <li>字体：<code>等宽中粗体</code></li>
            </ul>
            <p>对比默认主题下的 <code>行内代码</code> 样式差异。</p>
            """,
            family: .theme, tier: .nested, themeOverride: .customCodeTheme),
        DemoExample(id: "theme-mark-link", title: "自定义标记 + 链接", summary: "橙色高亮 + 紫色链接",
            html: """
            <h3>自定义内联样式</h3>
            <p>通过 <code>Mark {}</code> 和 <code>Link {}</code> DSL 可以独立控制每种内联元素的视觉。</p>
            <p>这是一段包含<mark>橙色高亮标记</mark>的文字。</p>
            <p>这是一个 <a href="https://example.com">紫色链接</a>，不再是默认的蓝色。</p>
            <p>还可以<mark>标记</mark>和 <a href="https://example.com">链接</a>同时出现在同一段落中。</p>
            """,
            family: .theme, tier: .nested, themeOverride: .customMarkLinkTheme),
        DemoExample(id: "theme-heading-override", title: "标题级别覆盖", summary: "h1红/h2蓝/h3绿 — LevelOverride 三级精度",
            html: """
            <h1>H1 红色标题</h1>
            <h2>H2 蓝色标题</h2>
            <h3>H3 绿色标题</h3>
            <h4>H4 橙色标题</h4>
            <h5>H5 紫色标题</h5>
            <h6>H6 青色标题</h6>
            <p>这是通过 HeadingTheme 的 <b>LevelOverride</b> 实现的：每个标题级别可以独立设置 textColor、fontSize、spacingBefore 等属性。</p>
            <blockquote>三级精度：base 默认 → per-level 覆盖 → 动态 resolve 闭包</blockquote>
            """,
            family: .theme, tier: .nested, themeOverride: .headingLevelOverrideTheme),
        DemoExample(id: "theme-dynamic-resolve", title: "动态 resolve 闭包", summary: "标题含 ⚠️ 自动变红",
            html: """
            <h2>正常标题</h2>
            <p>这个标题使用默认颜色。</p>
            <h2>⚠️ 警告标题</h2>
            <p>这个标题包含 ⚠️，通过 resolve 闭包自动变红。</p>
            <h2>另一个正常标题</h2>
            <p>不包含特殊符号的标题保持默认样式。</p>
            <h3>⚠️ 注意事项</h3>
            <p>H3 标题含 ⚠️ 也会触发 resolve 闭包。</p>
            """,
            family: .theme, tier: .nested, themeOverride: .dynamicResolveTheme),
        DemoExample(id: "theme-custom-prefor", title: "自定义代码块 + 引用", summary: "Preformatted 字体 + Blockquote 文字色",
            html: """
            <h3>自定义 Preformatted 和 Blockquote</h3>
            <p>通过 typed theme 精确控制每种块级元素的样式：</p>
            <pre>let theme = MarkupTheme { Preformatted { $0.font = .monospacedSystemFont(ofSize: 14, weight: .light) } }</pre>
            <blockquote>引用块使用了 secondaryLabel 文字色 + 增大缩进（20pt）。typed theme 让每个属性都可以独立配置，无需全局影响其他元素。</blockquote>
            <p>对比默认主题下的效果差异。</p>
            """,
            family: .theme, tier: .nested, themeOverride: .customPreforBlockquoteTheme),
        // MARK: 多主题并排（themeVariants）
        DemoExample(id: "theme-pipeline", title: "多主题对比", summary: "default / dark / article 三主题并排",
            html: """
            <h2>XMarkup 渲染引擎</h2>
            <p>XMarkup 是一个高性能的 <b>HTML 富文本解析引擎</b>，支持多种格式和样式。</p>
            <p>它使用 <code>render(theme:)</code> 方法将解析结果转换为 <code>AttributedString</code>。</p>
            <p>通过不同的 <a href="https://example.com/themes">MarkupTheme</a> 配置，同一内容可以有截然不同的呈现效果。</p>
            <blockquote>试试切换不同的主题，感受排版的差异。</blockquote>
            """,
            family: .theme, tier: .nested, themeVariants: [.default, .dark, .article]),
    ]
}
