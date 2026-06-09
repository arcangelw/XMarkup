# XMarkup Demo App 重新配置 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans` 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将 Demo App 从 3 Tab + 22 示例升级为 4 Tab（+WebView）+ ~39 示例，三端（UIKit/SwiftUI/AppKit）统一设计规范，新增段落排版/API 测试等示例。

**架构：** 共享数据层（DemoExamples + ThemePresets + WebViewRenderer）→ 各平台独立实现 WebView Tab + customTheme 渲染。SwiftUI 渲染从 UIViewRepresentable 改为原生 `Text(AttributedString)`。

**技术栈：** UIKit (UITextView + WKWebView) / SwiftUI (Text + WKWebView representable) / AppKit (NSTextView + WKWebView) / WebKit

---

## 文件结构

### 新建文件

| 文件 | 职责 |
|------|------|
| `Shared/ThemePresets.swift` | spacing 分类示例对应的 4 个自定义 ParagraphSpacing 主题 |
| `Shared/WebViewRenderer.swift` | 共享 HTML 注入 CSS 方法（`webViewCSSHTML(from:)`） |
| `UIKit/WebViewViewController.swift` | UIKit WKWebView 控制器，加载 HTML+CSS |
| `SwiftUI/WebViewPreviewView.swift` | `UIViewRepresentable` / `NSViewRepresentable` 包装 WKWebView |
| `AppKit/WebViewViewController.swift` | AppKit WKWebView 控制器，加载 HTML+CSS |

### 修改文件

| 文件 | 修改内容 |
|------|----------|
| `Shared/DemoExamples.swift` | 新增 `customTheme` / `secondHTML` 字段 + 4 个分类 + 14 个示例 |
| `UIKit/ExampleDetailViewController.swift` | 新增第 4 个 Tab（WebView），segment 从 3 段变 4 段 |
| `UIKit/RenderedTextViewController.swift` | 支持 customTheme + secondHTML 拼接渲染 |
| `SwiftUI/ExampleDetailView.swift` | 新增第 4 个 Tab（WebView），Picker 4 个选项 |
| `SwiftUI/RenderedTextView.swift` | 改用原生 `Text(AttributedString)` + customTheme + 多主题/拼接支持 |
| `AppKit/ExampleDetailViewController.swift` | 新增第 4 个 Tab（WebView），segment 从 3 段变 4 段 |
| `AppKit/RenderedTextViewController.swift` | 支持 customTheme + secondHTML 拼接渲染 |

所有文件基于 `playground/ios/XMarkupDemo/XMarkupDemo/` 目录。

---

## 任务 1：共享数据层 — DemoExample 结构体扩展 + ThemePresets

**文件：**
- 修改：`Shared/DemoExamples.swift`
- 创建：`Shared/ThemePresets.swift`

- [ ] **步骤 1：修改 DemoExample 结构体，添加新字段和分类**

在 `DemoExample` 结构体中添加两个可选字段，在 `Category` 枚举中添加 4 个新分类：

```swift
/// 预设 HTML 示例
struct DemoExample: Identifiable {
    let id: String
    let title: String
    let description: String
    let html: String
    let category: Category
    let customTheme: MarkupTheme?       // 新增：该示例使用的自定义主题
    let secondHTML: String?             // 新增：用于 api-append 拼接演示的第二段 HTML

    /// 便利初始化（无自定义主题和第二段 HTML）
    init(id: String, title: String, description: String, html: String, category: Category) {
        self.id = id
        self.title = title
        self.description = description
        self.html = html
        self.category = category
        self.customTheme = nil
        self.secondHTML = nil
    }

    /// 完整初始化（含自定义主题和第二段 HTML）
    init(id: String, title: String, description: String, html: String, category: Category, customTheme: MarkupTheme? = nil, secondHTML: String? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.html = html
        self.category = category
        self.customTheme = customTheme
        self.secondHTML = secondHTML
    }

    enum Category: String, CaseIterable {
        case basic = "基础格式"
        case color = "颜色"
        case heading = "标题"
        case link = "链接"
        case mixed = "混合样式"
        case complex = "复杂 HTML"
        case scenario = "场景实战"
        case media = "媒体"
        case boundary = "边界用例"      // 新增
        case spacing = "段落排版"       // 新增
        case longform = "长内容"        // 新增
        case apiTest = "API 测试"      // 新增
    }
}
```

- [ ] **步骤 2：创建 ThemePresets.swift**

创建 `Shared/ThemePresets.swift`，定义 spacing 分类的 4 个自定义主题：

```swift
import Foundation
import XMarkup

// MARK: - Spacing 示例专用主题

extension MarkupTheme {
    /// 紧凑排版：段前 2pt、段后 2pt
    static let spacingCompact: MarkupTheme = {
        var theme = MarkupTheme.default
        theme.paragraphSpacing = ParagraphSpacing(spacingBefore: 2, spacingAfter: 2)
        return theme
    }()

    /// 宽松排版 + 行距：段前 16pt、段后 16pt、行距 6pt
    static let spacingRelaxed: MarkupTheme = {
        var theme = MarkupTheme.default
        theme.paragraphSpacing = ParagraphSpacing(spacingBefore: 16, spacingAfter: 16, lineSpacing: 6)
        return theme
    }()

    /// 零间距：段前 0pt、段后 0pt
    static let spacingNone: MarkupTheme = {
        var theme = MarkupTheme.default
        theme.paragraphSpacing = ParagraphSpacing(spacingBefore: 0, spacingAfter: 0)
        return theme
    }()
}
```

- [ ] **步骤 3：Commit**

```bash
git add playground/ios/XMarkupDemo/XMarkupDemo/Shared/DemoExamples.swift \
        playground/ios/XMarkupDemo/XMarkupDemo/Shared/ThemePresets.swift
git commit -m "feat(demo): DemoExample 扩展 customTheme/secondHTML 字段 + 4 个新分类 + spacing 主题预设"
```

---

## 任务 2：共享数据层 — 新增 14 个示例

**文件：**
- 修改：`Shared/DemoExamples.swift`（在 `allExamples` 数组末尾追加）

- [ ] **步骤 1：在 `allExamples` 数组的 `media` 分类之后追加 4 个新分类的 14 个示例**

```swift
        // MARK: - 边界用例

        DemoExample(
            id: "emoji-only",
            title: "纯 Emoji",
            description: "仅包含 Emoji 字符",
            html: "🔄❤️🎉✨👀💬🔥💡🚀",
            category: .boundary
        ),
        DemoExample(
            id: "empty-doc",
            title: "空文档",
            description: "空字符串输入",
            html: "",
            category: .boundary
        ),
        DemoExample(
            id: "plain-text",
            title: "纯文本无标签",
            description: "无任何 HTML 标签的纯文字",
            html: "这是一段没有任何 HTML 标签的纯文字，只有普通字符和标点符号。它应该被正确解析为一个段落。",
            category: .boundary
        ),
        DemoExample(
            id: "unicode-mix",
            title: "Unicode 混合",
            description: "多语言 + Emoji 混合",
            html: "مرحبا 你好 こんにちは 안녕하세요 🌍 Héllo wörld",
            category: .boundary
        ),
        DemoExample(
            id: "nested-deep",
            title: "多层嵌套",
            description: "<b><i><u><s> 四层嵌套",
            html: "普通文字 <b><i><u><s>四层嵌套加粗斜体下划线删除线</s></u></i></b> 恢复普通",
            category: .boundary
        ),
        DemoExample(
            id: "html-entities",
            title: "HTML 实体转义",
            description: "&amp; &lt; &gt; 等实体",
            html: "常用实体：&amp; &lt; &gt; &quot; &#x1F600; 还有一些特殊字符：© ® ™",
            category: .boundary
        ),

        // MARK: - 段落排版

        DemoExample(
            id: "spacing-default",
            title: "默认间距",
            description: "ParagraphSpacing(8, 8, 0)",
            html: """
            <p>这是第一段文字，使用默认段落间距（段前 8pt、段后 8pt、行距 0）。</p>
            <p>这是第二段文字，注意观察段落之间的间距。合理的段落间距能显著提升阅读体验。</p>
            <p>这是第三段文字。每个 <code>&lt;p&gt;</code> 标签对应一个独立的段落 block。</p>
            <p>这是第四段文字。通过对比其他间距示例，可以直观感受不同配置的效果。</p>
            <h3>标题也参与段落间距</h3>
            <p>这是标题下方的第五段文字。</p>
            """,
            category: .spacing,
            customTheme: .default
        ),
        DemoExample(
            id: "spacing-compact",
            title: "紧凑排版",
            description: "ParagraphSpacing(2, 2, 0)",
            html: """
            <p>这是第一段文字，使用紧凑段落间距（段前 2pt、段后 2pt、行距 0）。</p>
            <p>这是第二段文字，紧凑排版适合信息密度高的场景，如列表、数据展示。</p>
            <p>这是第三段文字。段落之间几乎没有额外空白。</p>
            <p>这是第四段文字。紧凑排版可让更多内容在有限空间内展示。</p>
            <h3>紧凑标题</h3>
            <p>这是标题下方的第五段文字。</p>
            """,
            category: .spacing,
            customTheme: .spacingCompact
        ),
        DemoExample(
            id: "spacing-relaxed",
            title: "宽松排版 + 行距",
            description: "ParagraphSpacing(16, 16, 6)",
            html: """
            <p>这是第一段文字，使用宽松段落间距（段前 16pt、段后 16pt、行距 6pt）。</p>
            <p>这是第二段文字，宽松排版适合长文阅读场景，给眼睛更多呼吸空间。</p>
            <p>这是第三段文字。额外的行间距让每行文字更加清晰可辨。</p>
            <p>这是第四段文字。适合文章、书籍等需要舒适阅读体验的场景。</p>
            <h3>宽松标题</h3>
            <p>这是标题下方的第五段文字。</p>
            """,
            category: .spacing,
            customTheme: .spacingRelaxed
        ),
        DemoExample(
            id: "spacing-none",
            title: "零间距",
            description: "ParagraphSpacing(0, 0, 0)",
            html: """
            <p>这是第一段文字，使用零间距（段前 0pt、段后 0pt、行距 0pt）。</p>
            <p>这是第二段文字，段落之间没有任何额外间距，紧密相连。</p>
            <p>这是第三段文字。适用于需要精确控制排版的特殊场景。</p>
            <p>这是第四段文字。零间距让所有内容挤在一起。</p>
            <h3>零间距标题</h3>
            <p>这是标题下方的第五段文字。</p>
            """,
            category: .spacing,
            customTheme: .spacingNone
        ),

        // MARK: - 长内容

        DemoExample(
            id: "long-article",
            title: "完整技术文章",
            description: "~1000 字，含多级标题、段落、引用、代码、链接",
            html: """
            <h1>SwiftUI 性能优化完全指南</h1>
            <p>SwiftUI 作为 Apple 推出的声明式 UI 框架，在简化开发流程的同时，也带来了新的性能挑战。本文将从实际场景出发，系统讲解 SwiftUI 性能优化的核心策略。</p>

            <h2>一、视图重组与 diff 机制</h2>
            <p>SwiftUI 使用 <b>声明式 diff 算法</b> 来决定哪些视图需要更新。每次状态变化时，框架会重新求值 body 属性，并与前一次的结构进行对比。</p>
            <p>关键优化点在于减少 <i>不必要的视图重组</i>。当一个视图的输入没有变化时，它的 body 不应该被重新求值。</p>
            <blockquote>性能优化的第一原则：让 SwiftUI 只做必要的 diff。任何导致不必要 diff 的代码都是潜在的性能瓶颈。</blockquote>

            <h3>1.1 Equatable 优化</h3>
            <p>当视图的参数实现了 <code>Equatable</code> 协议时，SwiftUI 可以跳过不必要的 body 求值。使用 <code>.equatable()</code> 修饰符：</p>
            <p>通过实现 <code>Equatable</code>，你告诉 SwiftUI 何时视图真正需要更新，从而避免无意义的重绘。</p>

            <h3>1.2 @Observable 与细粒度追踪</h3>
            <p>Swift 5.9 引入的 <code>@Observable</code> 宏实现了<b>属性级依赖追踪</b>。相比旧的 <code>ObservableObject</code>，它能更精确地定位哪些属性发生了变化，从而减少视图更新范围。</p>
            <p>关键区别：<code>@Observable</code> 在访问属性时建立依赖，而非在视图初始化时订阅整个对象。</p>

            <h2>二、列表性能优化</h2>
            <p><code>LazyVStack</code> 和 <code>LazyHStack</code> 是处理大量数据的关键。它们只渲染可见区域的内容，避免一次性创建所有视图。</p>
            <p>使用 <code>List</code> 时，确保每个 row 的 <code>id</code> 稳定且唯一。不稳定的 id 会导致整个列表重新渲染。</p>

            <h3>2.1 识别模式</h3>
            <p>优先使用 <code>Identifiable</code> 协议而非 <code>ForEach(_, id:)</code> 闭包。后者在每次 diff 时都会调用闭包，增加计算开销。</p>

            <h3>2.2 图片加载优化</h3>
            <p>在列表中加载图片时，使用 <code>AsyncImage</code> 配合 <code>transaction</code> 控制动画。避免在滚动时触发大量并发图片请求。</p>
            <p>建议使用 <a href="https://developer.apple.com/documentation/swiftui/asyncimage">AsyncImage</a> 搭配自定义的图片缓存策略。</p>

            <h2>三、动画性能</h2>
            <p>SwiftUI 动画默认使用 <code>Core Animation</code>，在 GPU 上执行。但如果动画闭包中包含<b>非可动画属性</b>的变更，可能导致回退到 CPU 渲染。</p>
            <p>使用 <code>drawingGroup()</code> 修饰符将复杂视图组合并为单个 Metal 绘制调用，显著提升渲染性能。</p>

            <h4>小结</h4>
            <p>性能优化是一个持续迭代的过程。从 Instruments 工具出发，定位瓶颈，有针对性地优化，而不是盲目猜测。更多详情请参考 <a href="https://developer.apple.com/videos/">WWDC 视频</a>。</p>
            """,
            category: .longform
        ),
        DemoExample(
            id: "gallery",
            title: "多媒体相册",
            description: "6+ 张图片混合文字描述，展示图片占位和间距",
            html: """
            <h1>2026 夏日旅行相册</h1>
            <p>这次旅行横跨三个国家，用镜头记录了每一个难忘瞬间。</p>

            <h2>🇯🇵 日本 · 东京</h2>
            <p><img src="https://example.com/tokyo-tower.jpg"></p>
            <p>东京塔的夜景令人震撼，整座城市被灯光点亮，宛如星河倒映在大地上。</p>
            <p><img src="https://example.com/shibuya-crossing.jpg"></p>
            <p>涩谷十字路口，世界上最繁忙的人行横道。每次绿灯亮起，多达 3000 人同时穿越。</p>

            <h2>🇫🇷 法国 · 巴黎</h2>
            <p><img src="https://example.com/eiffel-tower.jpg"></p>
            <p>从战神广场仰望埃菲尔铁塔，黄昏时分的金色光芒洒满整座塔身。</p>
            <p><img src="https://example.com/louvre.jpg"></p>
            <p>卢浮宫前的玻璃金字塔，建筑大师贝聿铭的杰作。夜晚灯光映衬下更显神秘。</p>

            <h2>🇮🇹 意大利 · 罗马</h2>
            <p><img src="https://example.com/colosseum.jpg"></p>
            <p>罗马斗兽场，两千年历史的见证。站在废墟中，仿佛能听到角斗士的呐喊。</p>
            <p><img src="https://example.com/vatican.jpg"></p>
            <p>梵蒂冈圣彼得大教堂内部，米开朗基罗的穹顶令人叹为观止。</p>
            <p><img src="https://example.com/trevi-fountain.jpg"></p>
            <p>许愿池前抛一枚硬币，传说这样就能再次回到罗马 🪙</p>

            <p><i>全程使用 iPhone 16 Pro Max 拍摄，后期使用 <a href="https://example.com/lightroom">Lightroom</a> 调色。</i></p>
            """,
            category: .longform
        ),

        // MARK: - API 测试

        DemoExample(
            id: "api-append",
            title: "appending() 拼接",
            description: "两段独立 HTML 分别解析后 append",
            html: """
            <h3>第一段：核心特性</h3>
            <p>XMarkup 支持 <b>粗体</b>、<i>斜体</i>、<u>下划线</u> 等基础格式。</p>
            <p>还支持 <code>行内代码</code> 和 <a href="https://example.com">超链接</a>。</p>
            """,
            category: .apiTest,
            secondHTML: """
            <h3>第二段：高级特性</h3>
            <p>支持 <span style="color:#FF0000">彩色文字</span> 和 <span style="background-color:#FFFF00">高亮背景</span>。</p>
            <p>支持各级标题 <b>H1~H6</b> 和 <mark>标记高亮</mark>。</p>
            """
        ),
        DemoExample(
            id: "api-themes",
            title: "多主题对比",
            description: "同一 HTML 在 default/chat/article 三种主题下渲染",
            html: """
            <h2>XMarkup 渲染引擎</h2>
            <p>XMarkup 是一个高性能的 <b>HTML 富文本解析引擎</b>，支持多种格式和样式。</p>
            <p>它使用 <code>render(theme:)</code> 方法将解析结果转换为 <code>AttributedString</code>。</p>
            <p>通过不同的 <a href="https://example.com/themes">MarkupTheme</a> 配置，同一内容可以有截然不同的呈现效果。</p>
            <blockquote>试试切换不同的主题，感受排版的差异。</blockquote>
            """,
            category: .apiTest
        ),
```

注意：追加在 `media-mix` 示例的闭合 `)` 之后、数组结束 `]` 之前。现有 22 个示例无需修改。

- [ ] **步骤 2：验证编译**

```bash
cd /Users/arcangelw/GitHub/XMarkup && swift build 2>&1 | tail -5
```

预期：BUILD SUCCEEDED（Demo App 代码不在 SPM target 中，此步骤仅验证 import 语法正确）

- [ ] **步骤 3：Commit**

```bash
git add playground/ios/XMarkupDemo/XMarkupDemo/Shared/DemoExamples.swift
git commit -m "feat(demo): 新增 14 个示例 — boundary(6) + spacing(4) + longform(2) + apiTest(2)"
```

---

## 任务 3：共享 WebView 渲染器

**文件：**
- 创建：`Shared/WebViewRenderer.swift`

- [ ] **步骤 1：创建 WebViewRenderer.swift**

```swift
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
```

- [ ] **步骤 2：Commit**

```bash
git add playground/ios/XMarkupDemo/XMarkupDemo/Shared/WebViewRenderer.swift
git commit -m "feat(demo): 新增 WebViewRenderer 共享 HTML+CSS 注入工具"
```

---

## 任务 4：UIKit 平台 — WebView + 4th Tab + customTheme

**文件：**
- 创建：`UIKit/WebViewViewController.swift`
- 修改：`UIKit/ExampleDetailViewController.swift`
- 修改：`UIKit/RenderedTextViewController.swift`

- [ ] **步骤 1：创建 WebViewViewController.swift**

```swift
import UIKit
import WebKit

/// WebView HTML 渲染视图（UIKit）
///
/// 使用 WKWebView 加载原始 HTML，注入基础 CSS，展示浏览器渲染效果。
final class WebViewViewController: UIViewController {
    private let html: String
    private let webView = WKWebView()

    init(html: String) {
        self.html = html
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupWebView()
        loadHTML()
    }

    // MARK: - Setup

    private func setupWebView() {
        webView.navigationDelegate = self
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func loadHTML() {
        let styled = WebViewRenderer.styledHTML(from: html)
        webView.loadHTMLString(styled, baseURL: nil)
    }
}

// MARK: - WKNavigationDelegate

extension WebViewViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // 允许初始加载，阻止外部链接导航
        if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }
}
```

- [ ] **步骤 2：修改 ExampleDetailViewController.swift — 4 Tab**

完整替换为：

```swift
import UIKit

/// 示例详情：四段 Tab 切换（HTML 源码 / 渲染效果 / WebView / Span 数据）
final class ExampleDetailViewController: UIViewController {
    private let example: DemoExample
    private let segmentedControl = UISegmentedControl(items: ["HTML 源码", "渲染效果", "WebView", "Span 数据"])
    private let containerView = UIView()

    private var htmlVC: HTMLSourceViewController?
    private var renderedVC: RenderedTextViewController?
    private var webViewVC: WebViewViewController?
    private var spanVC: SpanDataViewController?

    init(example: DemoExample) {
        self.example = example
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = example.title
        view.backgroundColor = .systemBackground

        setupSegmentedControl()
        setupContainer()
        setupChildViewControllers()
    }

    // MARK: - Setup

    private func setupSegmentedControl() {
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.addAction(UIAction { [weak self] _ in
            self?.switchTab()
        }, for: .valueChanged)

        view.addSubview(segmentedControl)
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])
    }

    private func setupContainer() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    /// 一次性创建并添加所有子控制器，通过 isHidden 切换显示
    private func setupChildViewControllers() {
        htmlVC = HTMLSourceViewController(html: example.html)
        renderedVC = RenderedTextViewController(example: example)
        webViewVC = WebViewViewController(html: example.html)
        spanVC = SpanDataViewController(example: example)

        let children: [UIViewController] = [htmlVC!, renderedVC!, webViewVC!, spanVC!]
        for child in children {
            addChild(child)
            containerView.addSubview(child.view)
            child.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                child.view.topAnchor.constraint(equalTo: containerView.topAnchor),
                child.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                child.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                child.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            ])
            child.didMove(toParent: self)
            child.view.isHidden = true
        }

        // 默认显示第一个 Tab
        htmlVC?.view.isHidden = false
    }

    // MARK: - Tab Switching

    private func switchTab() {
        htmlVC?.view.isHidden = segmentedControl.selectedSegmentIndex != 0
        renderedVC?.view.isHidden = segmentedControl.selectedSegmentIndex != 1
        webViewVC?.view.isHidden = segmentedControl.selectedSegmentIndex != 2
        spanVC?.view.isHidden = segmentedControl.selectedSegmentIndex != 3
    }
}
```

- [ ] **步骤 3：修改 RenderedTextViewController.swift — customTheme + 拼接**

完整替换为：

```swift
import UIKit
import XMarkup

/// NSAttributedString 渲染视图（UIKit）
///
/// 支持 customTheme 和 secondHTML 拼接渲染。
final class RenderedTextViewController: UIViewController {
    private let example: DemoExample
    private let textView = UITextView()

    init(example: DemoExample) {
        self.example = example
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTextView()
        parseAndRender()
    }

    // MARK: - Setup

    private func setupTextView() {
        textView.isEditable = false
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.backgroundColor = .clear
        textView.linkTextAttributes = [:]
        textView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.topAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])
    }

    // MARK: - Parse

    private func parseAndRender() {
        do {
            let theme: MarkupTheme = example.customTheme ?? .default
            let document = try parseDocument()
            let renderer = NSAttributedStringRenderer()
            textView.attributedText = renderer.render(document.render(theme: theme))
        } catch {
            textView.text = "解析错误：\(error.localizedDescription)"
            textView.textColor = .systemRed
        }
    }

    /// 解析文档，支持 secondHTML 拼接
    private func parseDocument() throws -> MarkupDocument {
        let parser = try XMarkupParser()
        let result1 = try parser.parse(example.html)
        let doc1 = MarkupDocument.from(result1)

        if let secondHTML = example.secondHTML {
            let result2 = try parser.parse(secondHTML)
            let doc2 = MarkupDocument.from(result2)
            return doc1.appending(doc2)
        }

        return doc1
    }
}
```

- [ ] **步骤 4：Commit**

```bash
git add playground/ios/XMarkupDemo/XMarkupDemo/UIKit/WebViewViewController.swift \
        playground/ios/XMarkupDemo/XMarkupDemo/UIKit/ExampleDetailViewController.swift \
        playground/ios/XMarkupDemo/XMarkupDemo/UIKit/RenderedTextViewController.swift
git commit -m "feat(demo): UIKit WebView Tab + customTheme + appending 支持"
```

---

## 任务 5：SwiftUI 平台 — WebView + 4th Tab + 原生 Text

**文件：**
- 创建：`SwiftUI/WebViewPreviewView.swift`
- 修改：`SwiftUI/ExampleDetailView.swift`
- 修改：`SwiftUI/RenderedTextView.swift`

- [ ] **步骤 1：创建 WebViewPreviewView.swift**

```swift
import SwiftUI
import WebKit

/// SwiftUI WebView 包装
///
/// iOS 使用 UIViewRepresentable 包装 WKWebView，
/// macOS 使用 NSViewRepresentable 包装 WKWebView。
/// 统一在一个文件中，通过条件编译适配平台。
#if canImport(UIKit)
struct WebViewPreviewView: UIViewRepresentable {
    let html: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let styled = WebViewRenderer.styledHTML(from: html)
        webView.loadHTMLString(styled, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}
#elseif canImport(AppKit)
struct WebViewPreviewView: NSViewRepresentable {
    let html: String

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let styled = WebViewRenderer.styledHTML(from: html)
        webView.loadHTMLString(styled, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}
#endif
```

- [ ] **步骤 2：修改 ExampleDetailView.swift — 4 Tab**

完整替换为：

```swift
import SwiftUI

/// 示例详情页：四段 Tab（HTML 源码 / 渲染效果 / WebView / Span 数据）
struct ExampleDetailView: View {
    let example: DemoExample
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("视图", selection: $selectedTab) {
                Text("HTML 源码").tag(0)
                Text("渲染效果").tag(1)
                Text("WebView").tag(2)
                Text("Span 数据").tag(3)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            contentView
        }
        .navigationTitle(example.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case 0:
            HTMLSourceView(html: example.html)
        case 1:
            RenderedTextView(example: example)
        case 2:
            WebViewPreviewView(html: example.html)
        case 3:
            SpanDataView(example: example)
        default:
            EmptyView()
        }
    }
}
```

- [ ] **步骤 3：修改 RenderedTextView.swift — 原生 Text + customTheme + 多主题/拼接**

完整替换为：

```swift
import SwiftUI
import XMarkup

/// AttributedString 渲染视图（SwiftUI）
///
/// 使用原生 `Text(AttributedString)` 渲染（不使用 UIViewRepresentable）。
/// 支持 customTheme、secondHTML 拼接、多主题对比。
struct RenderedTextView: View {
    let example: DemoExample
    @State private var renderResult: RenderResult?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            Group {
                if let error = errorMessage {
                    errorView(error)
                } else if let result = renderResult {
                    renderContent(result)
                } else {
                    ProgressView()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .task { parseHTML() }
    }

    // MARK: - Render Content

    /// 根据示例类型选择渲染模式
    @ViewBuilder
    private func renderContent(_ result: RenderResult) -> some View {
        if result.isMultiTheme {
            multiThemeContent(result)
        } else {
            Text(result.attributedStrings[0])
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 多主题对比：每个主题一行标题 + 渲染结果
    private func multiThemeContent(_ result: RenderResult) -> some View {
        let themeNames = ["默认主题", "聊天主题", "文章主题"]
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(result.attributedStrings.enumerated()), id: \.offset) { index, attrStr in
                VStack(alignment: .leading, spacing: 4) {
                    Text(themeNames[index])
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 2)
                    Text(attrStr)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("解析错误", systemImage: "exclamationmark.triangle")
                .font(.headline)
                .foregroundStyle(.red)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Parse

    /// 渲染结果：多主题时包含多个 AttributedString
    private struct RenderResult {
        let attributedStrings: [AttributedString]
        let isMultiTheme: Bool
    }

    private func parseHTML() {
        do {
            let parser = try XMarkupParser()

            if example.id == "api-themes" {
                // 多主题对比
                let result = try parser.parse(example.html)
                let document = MarkupDocument.from(result)
                let themes: [MarkupTheme] = [.default, .chat, .article]
                let strings = themes.map { document.render(theme: $0) }
                renderResult = RenderResult(attributedStrings: strings, isMultiTheme: true)
            } else {
                // 单主题（含 customTheme 和 secondHTML 拼接）
                let document = try parseDocument(parser: parser)
                let theme: MarkupTheme = example.customTheme ?? .default
                let attrStr = document.render(theme: theme)
                renderResult = RenderResult(attributedStrings: [attrStr], isMultiTheme: false)
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            renderResult = nil
        }
    }

    /// 解析文档，支持 secondHTML 拼接
    private func parseDocument(parser: XMarkupParser) throws -> MarkupDocument {
        let result1 = try parser.parse(example.html)
        let doc1 = MarkupDocument.from(result1)

        if let secondHTML = example.secondHTML {
            let result2 = try parser.parse(secondHTML)
            let doc2 = MarkupDocument.from(result2)
            return doc1.appending(doc2)
        }

        return doc1
    }
}
```

- [ ] **步骤 4：Commit**

```bash
git add playground/ios/XMarkupDemo/XMarkupDemo/SwiftUI/WebViewPreviewView.swift \
        playground/ios/XMarkupDemo/XMarkupDemo/SwiftUI/ExampleDetailView.swift \
        playground/ios/XMarkupDemo/XMarkupDemo/SwiftUI/RenderedTextView.swift
git commit -m "feat(demo): SwiftUI WebView Tab + 原生 Text 渲染 + customTheme + 多主题对比"
```

---

## 任务 6：AppKit 平台 — WebView + 4th Tab + customTheme

**文件：**
- 创建：`AppKit/WebViewViewController.swift`
- 修改：`AppKit/ExampleDetailViewController.swift`
- 修改：`AppKit/RenderedTextViewController.swift`

- [ ] **步骤 1：创建 WebViewViewController.swift**

```swift
import AppKit
import WebKit

/// WebView HTML 渲染视图（AppKit）
final class WebViewViewController: NSViewController {
    private let html: String
    private let webView = WKWebView()

    init(html: String) {
        self.html = html
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupWebView()
        loadHTML()
    }

    // MARK: - Setup

    private func setupWebView() {
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func loadHTML() {
        let styled = WebViewRenderer.styledHTML(from: html)
        webView.loadHTMLString(styled, baseURL: nil)
    }
}

// MARK: - WKNavigationDelegate

extension WebViewViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }
}
```

- [ ] **步骤 2：修改 ExampleDetailViewController.swift — 4 Tab**

在现有代码基础上修改（保留 AppKit 特有的 splitView 模式）：
- `NSSegmentedControl` 的 labels 从 `["HTML 源码", "渲染效果", "Span 数据"]` 改为 `["HTML 源码", "渲染效果", "WebView", "Span 数据"]`
- 新增 `webViewVC` 属性
- `update(example:)` 中创建 WebViewViewController
- `switchTab()` 中处理 4 个 Tab

完整替换为：

```swift
import AppKit

/// 详情页：四段 Tab 切换（HTML 源码 / 渲染效果 / WebView / Span 数据）
final class ExampleDetailViewController: NSViewController {
    private let containerView = NSView()
    private let segmentedControl = NSSegmentedControl(
        labels: ["HTML 源码", "渲染效果", "WebView", "Span 数据"],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )

    private var htmlVC: HTMLSourceViewController?
    private var renderedVC: RenderedTextViewController?
    private var webViewVC: WebViewViewController?
    private var spanVC: SpanDataViewController?

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupLayout()
    }

    private func setupLayout() {
        segmentedControl.selectedSegment = 0
        segmentedControl.target = self
        segmentedControl.action = #selector(switchTab)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.setContentHuggingPriority(.required, for: .vertical)

        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.setContentHuggingPriority(.defaultLow, for: .vertical)

        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.edgeInsets = NSEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        stackView.addArrangedSubview(segmentedControl)
        stackView.addArrangedSubview(containerView)

        view.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: view.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        showPlaceholder()
    }

    private func showPlaceholder() {
        let label = NSTextField(labelWithString: "请从左侧选择一个示例")
        label.font = .systemFont(ofSize: 16)
        label.textColor = .tertiaryLabelColor
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
        ])
    }

    // MARK: - Public

    func update(example: DemoExample) {
        // 清理旧的子控制器
        htmlVC?.view.removeFromSuperview()
        htmlVC?.removeFromParent()
        renderedVC?.view.removeFromSuperview()
        renderedVC?.removeFromParent()
        webViewVC?.view.removeFromSuperview()
        webViewVC?.removeFromParent()
        spanVC?.view.removeFromSuperview()
        spanVC?.removeFromParent()
        containerView.subviews.forEach { $0.removeFromSuperview() }

        // 创建新的子控制器
        htmlVC = HTMLSourceViewController(html: example.html)
        renderedVC = RenderedTextViewController(example: example)
        webViewVC = WebViewViewController(html: example.html)
        spanVC = SpanDataViewController(example: example)

        let children: [NSViewController] = [htmlVC!, renderedVC!, webViewVC!, spanVC!]
        for child in children {
            addChild(child)
            child.view.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(child.view)
            NSLayoutConstraint.activate([
                child.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                child.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                child.view.topAnchor.constraint(equalTo: containerView.topAnchor),
                child.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            ])
            child.view.isHidden = true
        }

        htmlVC?.view.isHidden = false
        segmentedControl.selectedSegment = 0
    }

    // MARK: - Actions

    @objc private func switchTab() {
        htmlVC?.view.isHidden = segmentedControl.selectedSegment != 0
        renderedVC?.view.isHidden = segmentedControl.selectedSegment != 1
        webViewVC?.view.isHidden = segmentedControl.selectedSegment != 2
        spanVC?.view.isHidden = segmentedControl.selectedSegment != 3
        containerView.layoutSubtreeIfNeeded()
    }
}
```

- [ ] **步骤 3：修改 RenderedTextViewController.swift — customTheme + 拼接**

在 `parseAndRender()` 方法中添加 customTheme 和 secondHTML 支持。完整替换为：

```swift
import AppKit
import XMarkup

/// NSAttributedString 渲染视图（AppKit）
///
/// 支持 customTheme 和 secondHTML 拼接渲染。
final class RenderedTextViewController: NSViewController {
    private let example: DemoExample
    private let scrollView = NSScrollView()
    private let textView = NSTextView()

    init(example: DemoExample) {
        self.example = example
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTextView()
        parseAndRender()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        let visibleRect = scrollView.documentVisibleRect
        if visibleRect.width > 0 {
            let contentHeight = textView.layoutManager?.usedRect(for: textView.textContainer!).height ?? 0
            textView.frame = NSRect(
                x: 0, y: 0,
                width: visibleRect.width,
                height: max(visibleRect.height, contentHeight + 20)
            )
        }
    }

    private func setupTextView() {
        textView.isEditable = false
        textView.isRichText = true
        textView.backgroundColor = .clear
        textView.typingAttributes = [.font: NSFont.systemFont(ofSize: 16)]
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.linkTextAttributes = [:]

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false

        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        scrollView.documentView = textView
    }

    private func parseAndRender() {
        do {
            let theme: MarkupTheme = example.customTheme ?? .default
            let document = try parseDocument()
            let renderer = NSAttributedStringRenderer()
            let attributed = renderer.render(document.render(theme: theme))
            textView.textStorage?.setAttributedString(attributed)
        } catch {
            textView.string = "解析错误：\(error.localizedDescription)"
            textView.textColor = .systemRed
        }
    }

    /// 解析文档，支持 secondHTML 拼接
    private func parseDocument() throws -> MarkupDocument {
        let parser = try XMarkupParser()
        let result1 = try parser.parse(example.html)
        let doc1 = MarkupDocument.from(result1)

        if let secondHTML = example.secondHTML {
            let result2 = try parser.parse(secondHTML)
            let doc2 = MarkupDocument.from(result2)
            return doc1.appending(doc2)
        }

        return doc1
    }
}
```

- [ ] **步骤 4：Commit**

```bash
git add playground/ios/XMarkupDemo/XMarkupDemo/AppKit/WebViewViewController.swift \
        playground/ios/XMarkupDemo/XMarkupDemo/AppKit/ExampleDetailViewController.swift \
        playground/ios/XMarkupDemo/XMarkupDemo/AppKit/RenderedTextViewController.swift
git commit -m "feat(demo): AppKit WebView Tab + customTheme + appending 支持"
```

---

## 任务 7：Span 数据视图 — secondHTML 拼接支持

**文件：**
- 修改：`UIKit/SpanDataViewController.swift`
- 修改：`SwiftUI/SpanDataView.swift`
- 修改：`AppKit/SpanDataViewController.swift`

三端的 Span 数据视图当前只解析 `example.html`。对于 `api-append` 示例，需要解析拼接后的文档才能正确展示 span 数据。

- [ ] **步骤 1：修改 UIKit SpanDataViewController.swift — parseHTML 方法**

将 `parseHTML()` 方法替换为支持 secondHTML 拼接的版本：

```swift
    private func parseHTML() {
        do {
            let parser = try XMarkupParser()
            if let secondHTML = example.secondHTML {
                // 拼接场景：合并两段 HTML 的解析结果
                let result1 = try parser.parse(example.html)
                let result2 = try parser.parse(secondHTML)
                // 合并纯文本和 spans
                let textLength = result1.text.utf16.count
                let combinedText = result1.text + result2.text
                let combinedSpans = result1.spans + result2.spans.map { span in
                    XMarkupSpan(tag: span.tag, style: span.style, range: NSRange(location: span.range.location + textLength, length: span.range.length), value: span.value)
                }
                // 用第一段结果作为基础，替换为合并数据
                result = try parser.parse(combinedText)
                // 注意：上面会重新解析纯文本，span 数据可能不准确
                // 改为直接使用两段结果的展示方式
                result = result1  // 先用第一段，展示原始 span
            } else {
                result = try parser.parse(example.html)
            }
        } catch {
            result = nil
        }
        tableView.reloadData()
    }
```

**等一下**，上面的方案太复杂了。Span Data 视图的目的是展示原始解析结果。对于 `api-append` 示例，最好的方式是展示两段分别解析的 span 数据。让我简化方案：

**简化方案**：Span Data 视图对 `api-append` 示例展示两段独立的 span 数据（两个 section），不做合并。因为 span 数据展示的是底层 C 解析结果，合并 span 的 range 偏移没有实际意义。

修改 UIKit `SpanDataViewController.swift`：

1. 添加 `secondResult` 属性
2. 修改 `parseHTML()` 解析两段
3. 修改 section 和 row 逻辑

完整替换 `parseHTML()` 及 `UITableViewDataSource`：

```swift
    private var secondResult: XMarkupResult?

    // MARK: - Parse

    private func parseHTML() {
        do {
            let parser = try XMarkupParser()
            result = try parser.parse(example.html)
            if let secondHTML = example.secondHTML {
                secondResult = try parser.parse(secondHTML)
            }
        } catch {
            result = nil
        }
        tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource

extension SpanDataViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        let baseSections = 2 // 纯文本 + Span 列表
        return secondResult != nil ? baseSections + 2 : baseSections
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let result else { return 0 }
        let secondResult = self.secondResult

        switch section {
        case 0: return 1  // 纯文本
        case 1: return result.spans.count
        case 2: return 1  // 第二段纯文本
        case 3: return secondResult?.spans.count ?? 0
        default: return 0
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard result != nil else { return nil }
        switch section {
        case 0: return "纯文本"
        case 1: return "Span 列表（\(result?.spans.count ?? 0) 个）"
        case 2: return "第二段纯文本"
        case 3: return "第二段 Span 列表（\(secondResult?.spans.count ?? 0) 个）"
        default: return nil
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SpanCell", for: indexPath)
        var config = cell.defaultContentConfiguration()

        guard let result else {
            config.text = "解析错误"
            cell.contentConfiguration = config
            return cell
        }

        switch indexPath.section {
        case 0:
            config.text = result.text
            config.textProperties.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        case 1:
            let span = result.spans[indexPath.row]
            config.text = "#\(indexPath.row + 1)  \(tagDescription(span.tag))"
            config.secondaryText = """
            tag: \(tagDescription(span.tag))
            style: \(styleDescription(span.style))
            range: [\(span.range.location), \(span.range.location + span.range.length))
            \(span.value.map { "value: \($0)" } ?? "")
            """
            config.secondaryTextProperties.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            config.secondaryTextProperties.color = .secondaryLabel
        case 2:
            config.text = secondResult?.text ?? ""
            config.textProperties.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        case 3:
            guard let secondResult, indexPath.row < secondResult.spans.count else { break }
            let span = secondResult.spans[indexPath.row]
            config.text = "#\(indexPath.row + 1)  \(tagDescription(span.tag))"
            config.secondaryText = """
            tag: \(tagDescription(span.tag))
            style: \(styleDescription(span.style))
            range: [\(span.range.location), \(span.range.location + span.range.length))
            \(span.value.map { "value: \($0)" } ?? "")
            """
            config.secondaryTextProperties.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            config.secondaryTextProperties.color = .secondaryLabel
        default:
            break
        }

        cell.contentConfiguration = config
        return cell
    }
```

注意：`tagDescription` 和 `styleDescription` 方法保持不变。

- [ ] **步骤 2：修改 SwiftUI SpanDataView.swift — 支持 secondResult**

在 `SpanDataView` 中添加 `@State private var secondResult: XMarkupResult?`，修改 `parseHTML()` 和 body 中的 section 布局：

在现有 `@State` 声明下方添加：
```swift
    @State private var secondResult: XMarkupResult?
```

修改 `parseHTML()`：
```swift
    private func parseHTML() {
        do {
            let parser = try XMarkupParser()
            result = try parser.parse(example.html)
            if let secondHTML = example.secondHTML {
                secondResult = try parser.parse(secondHTML)
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            result = nil
        }
    }
```

在 `body` 的 `else if let result` 分支中，添加第二段 section：
```swift
            } else if let result {
                plainTextSection(result)
                spansSection(result.spans)
                if let secondResult {
                    Section {
                        Text(secondResult.text)
                            .font(.system(.body, design: .monospaced))
                    } header: {
                        Text("第二段纯文本")
                    }
                    spansSection(secondResult.spans)
                }
            }
```

- [ ] **步骤 3：修改 AppKit SpanDataViewController.swift — 支持 secondResult**

添加 `private var secondResult: XMarkupResult?` 属性，修改 `parseHTML()` 和数据源方法。

在属性声明区添加：
```swift
    private var secondResult: XMarkupResult?
```

修改 `parseHTML()`：
```swift
    private func parseHTML() {
        do {
            let parser = try XMarkupParser()
            result = try parser.parse(example.html)
            if let secondHTML = example.secondHTML {
                secondResult = try parser.parse(secondHTML)
            }
        } catch {
            result = nil
        }
        tableView.reloadData()
    }
```

修改 `numberOfRowsInTableView`：
```swift
    func numberOfRows(in tableView: NSTableView) -> Int {
        guard let result else { return 1 }
        if let secondResult {
            return result.spans.count + secondResult.spans.count + 2 // 两段纯文本 + 所有 span
        }
        return result.spans.isEmpty ? 1 : result.spans.count
    }
```

修改 `tableView(_:viewFor:row:)`，在 row >= result.spans.count 时展示第二段数据：
```swift
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("Cell"), owner: self) as? NSTableCellView
            ?? NSTableCellView()

        cell.subviews.forEach { $0.removeFromSuperview() }

        guard let result else {
            let label = NSTextField(labelWithString: "解析错误")
            label.textColor = .systemRed
            cell.addSubview(label)
            cell.identifier = NSUserInterfaceItemIdentifier("Cell")
            return cell
        }

        // 如果有第二段结果，展示分隔行 + 第二段 span
        if let secondResult {
            if row == 0 {
                // 第一段纯文本
                let label = NSTextField(labelWithString: "第一段：\(result.text)")
                label.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
                label.lineBreakMode = .byTruncatingTail
                label.translatesAutoresizingMaskIntoConstraints = false
                cell.addSubview(label)
                NSLayoutConstraint.activate([label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4), label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4)])
            } else if row <= result.spans.count {
                let span = result.spans[row - 1]
                buildSpanCell(cell, index: row - 1, span: span)
            } else if row == result.spans.count + 1 {
                let label = NSTextField(labelWithString: "第二段：\(secondResult.text)")
                label.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
                label.lineBreakMode = .byTruncatingTail
                label.translatesAutoresizingMaskIntoConstraints = false
                cell.addSubview(label)
                NSLayoutConstraint.activate([label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4), label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4)])
            } else {
                let secondIndex = row - result.spans.count - 2
                if secondIndex < secondResult.spans.count {
                    let span = secondResult.spans[secondIndex]
                    buildSpanCell(cell, index: secondIndex, span: span)
                }
            }
        } else {
            if result.spans.isEmpty {
                let label = NSTextField(labelWithString: "无 Span 数据")
                label.textColor = .tertiaryLabelColor
                cell.addSubview(label)
            } else {
                let span = result.spans[row]
                buildSpanCell(cell, index: row, span: span)
            }
        }

        cell.identifier = NSUserInterfaceItemIdentifier("Cell")
        return cell
    }

    private func buildSpanCell(_ cell: NSTableCellView, index: Int, span: XMarkupSpan) {
        let titleLabel = NSTextField(labelWithString: "#\(index + 1)  \(tagDescription(span.tag))")
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let rangeEnd = span.range.location + span.range.length
        var detailText = "tag: \(tagDescription(span.tag)) | style: \(styleDescription(span.style)) | range: [\(span.range.location), \(rangeEnd))"
        if let value = span.value {
            detailText += " | value: \(value)"
        }
        let detailLabel = NSTextField(labelWithString: detailText)
        detailLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.lineBreakMode = .byTruncatingTail
        detailLabel.translatesAutoresizingMaskIntoConstraints = false

        cell.addSubview(titleLabel)
        cell.addSubview(detailLabel)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            titleLabel.topAnchor.constraint(equalTo: cell.topAnchor, constant: 4),
            detailLabel.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            detailLabel.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
        ])
    }
```

- [ ] **步骤 4：Commit**

```bash
git add playground/ios/XMarkupDemo/XMarkupDemo/UIKit/SpanDataViewController.swift \
        playground/ios/XMarkupDemo/XMarkupDemo/SwiftUI/SpanDataView.swift \
        playground/ios/XMarkupDemo/XMarkupDemo/AppKit/SpanDataViewController.swift
git commit -m "feat(demo): Span 数据视图支持 secondHTML 拼接展示（三端统一）"
```

---

## 任务 8：构建验证 + 最终提交

- [ ] **步骤 1：Xcode 构建验证（macOS AppKit target）**

```bash
cd /Users/arcangelw/GitHub/XMarkup
xcodebuild build \
    -project playground/ios/XMarkupDemo/XMarkupDemo.xcodeproj \
    -scheme "XMarkupDemo (AppKit)" \
    -destination "platform=macOS" \
    -quiet 2>&1 | tail -10
```

预期：**BUILD SUCCEEDED**

注意：如果 scheme 名称不同，先运行：
```bash
xcodebuild -project playground/ios/XMarkupDemo/XMarkupDemo.xcodeproj -list
```
获取正确的 scheme 名称。

- [ ] **步骤 2：SPM 测试回归验证**

```bash
cd /Users/arcangelw/GitHub/XMarkup && swift test 2>&1 | tail -5
```

预期：148 测试全部通过（Demo App 变更不影响 SPM target）

- [ ] **步骤 3：最终 commit（如有未提交文件）**

```bash
git add -A playground/ios/XMarkupDemo/
git status
```

确认无遗漏文件后，如有未提交的变更：
```bash
git commit -m "chore(demo): Demo App 重新配置收尾"
```

---

## 自检

### 1. 规格覆盖度

| 规格需求 | 对应任务 |
|---------|---------|
| §1.2 组件映射表 | 任务 4/5/6（各平台原生组件） |
| §1.3 四 Tab 结构 | 任务 4/5/6（三端统一 Tab） |
| §1.4 间距/边距规范 | 任务 4/5/6（遵循现有间距常量） |
| §2.1 HTML 源码 Tab | 保留现有实现，无变更 |
| §2.2 渲染效果 Tab + customTheme | 任务 4/5/6 |
| §2.3 WebView Tab | 任务 3/4/5/6 |
| §2.4 Span 数据 Tab + secondHTML | 任务 7 |
| §3.1 新增 4 分类 | 任务 1 |
| §3.2 边界用例 6 个 | 任务 2 |
| §3.3 段落排版 4 个 + customTheme | 任务 1 + 2 |
| §3.4 长内容 2 个 | 任务 2 |
| §3.5 API 测试 2 个 | 任务 2 + 4/5/6/7 |
| DemoExample.customTheme 字段 | 任务 1 |
| 新建 WebViewRenderer.swift | 任务 3 |
| 新建 ThemePresets.swift | 任务 1 |
| 新建 WebViewVC（三端） | 任务 4/5/6 |
| SwiftUI 原生 Text | 任务 5 |

### 2. 占位符扫描

- ✅ 无 "TODO"/"TBD"/"待定"/"后续实现"
- ✅ 所有代码步骤包含完整代码
- ✅ 无 "类似任务 N" 引用

### 3. 类型一致性

- `DemoExample.customTheme: MarkupTheme?` — 与 `MarkupTheme` 类型一致
- `DemoExample.secondHTML: String?` — String 类型
- `WebViewRenderer.styledHTML(from:)` — 返回 `String`，传给 `WKWebView.loadHTMLString`
- `document.render(theme:)` — 返回 `AttributedString`
- `NSAttributedStringRenderer.render(_:)` — 接收 `AttributedString`，返回 `NSAttributedString`
- `MarkupDocument.appending(_:)` — 返回 `MarkupDocument`
- `ParagraphSpacing(spacingBefore:spacingAfter:lineSpacing:)` — 初始化器签名匹配
- `XMarkupResult.spans` — `[XMarkupSpan]`，`span.range` 为 `NSRange`

---

## 执行交接

计划已完成并保存到 `docs/superpowers/plans/2026-06-09-xmarkup-demo-app-redesign.md`。两种执行方式：

**1. 子代理驱动（推荐）** — 每个任务调度一个新的子代理，任务间进行审查，快速迭代

**2. 内联执行** — 在当前会话中批量执行并设有检查点

选哪种方式？
