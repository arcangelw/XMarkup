import Foundation
import XMarkup

/// 预设 HTML 示例
struct DemoExample: Identifiable {
    let id: String
    let title: String
    let description: String
    let html: String
    let category: Category
    let customTheme: MarkupTheme?       // 该示例使用的自定义主题
    let secondHTML: String?             // 用于 api-append 拼接演示的第二段 HTML

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
        case boundary = "边界用例"
        case spacing = "段落排版"
        case longform = "长内容"
        case apiTest = "API 测试"
    }
}

extension DemoExample {
    static let allExamples: [DemoExample] = [
        // MARK: - 基础格式

        DemoExample(
            id: "bold",
            title: "粗体",
            description: "<b> 标签",
            html: "这是<b>粗体</b>文字示例，展示基本加粗效果。",
            category: .basic
        ),
        DemoExample(
            id: "italic",
            title: "斜体",
            description: "<i> 标签",
            html: "这是<i>斜体</i>文字示例，展示基本倾斜效果。",
            category: .basic
        ),
        DemoExample(
            id: "underline",
            title: "下划线",
            description: "<u> 标签",
            html: "这是<u>下划线</u>文字示例。",
            category: .basic
        ),
        DemoExample(
            id: "strikethrough",
            title: "删除线",
            description: "<s> / <del> 标签",
            html: "这是<s>删除线</s>文字示例，原价 <del>¥99</del> 现价 ¥49。",
            category: .basic
        ),
        DemoExample(
            id: "bold-italic",
            title: "粗体 + 斜体",
            description: "嵌套样式合并",
            html: "这是<b><i>粗斜体</i></b>文字，展示<b>嵌套<b><i>组合</i></b>效果</b>。",
            category: .basic
        ),

        // MARK: - 颜色

        DemoExample(
            id: "text-color",
            title: "文字颜色",
            description: "style=\"color:#RRGGBB\"",
            html: "<span style=\"color:#FF0000\">红色文字</span> 和 <span style=\"color:#0000FF\">蓝色文字</span>。",
            category: .color
        ),
        DemoExample(
            id: "bg-color",
            title: "背景颜色",
            description: "style=\"background-color:#RRGGBB\"",
            html: "<span style=\"background-color:#FFFF00\">黄色背景</span> 的文字。",
            category: .color
        ),
        DemoExample(
            id: "combined-color",
            title: "文字 + 背景色",
            description: "同时指定前景色和背景色",
            html: "<span style=\"color:#FFFFFF;background-color:#333333\">白字灰底</span> 的文字。",
            category: .color
        ),

        // MARK: - 标题

        DemoExample(
            id: "headings",
            title: "H1 ~ H6 标题",
            description: "各级标题缩放",
            html: "<h1>一级标题</h1><h2>二级标题</h2><h3>三级标题</h3><h4>四级标题</h4><h5>五级标题</h5><h6>六级标题</h6>",
            category: .heading
        ),

        // MARK: - 链接

        DemoExample(
            id: "link",
            title: "超链接",
            description: "<a href=\"...\"> 标签",
            html: "访问 <a href=\"https://github.com\">GitHub</a> 了解更多。",
            category: .link
        ),
        DemoExample(
            id: "link-colored",
            title: "带颜色的链接",
            description: "链接 + 样式组合",
            html: "点击 <a href=\"https://example.com\"><span style=\"color:#FF6600\">橙色链接</span></a>。",
            category: .link
        ),

        // MARK: - 混合样式

        DemoExample(
            id: "font-size",
            title: "自定义字号",
            description: "style=\"font-size:Npx\"",
            html: "默认字号 / <span style=\"font-size:24px\">大号字</span> / <span style=\"font-size:10px\">小号字</span>。",
            category: .mixed
        ),
        DemoExample(
            id: "code",
            title: "行内代码",
            description: "<code> 标签",
            html: "使用 <code>print(\"Hello\")</code> 输出文本。",
            category: .mixed
        ),
        DemoExample(
            id: "mark",
            title: "高亮标记",
            description: "<mark> 标签",
            html: "请重点阅读<mark>这段内容</mark>。",
            category: .mixed
        ),

        // MARK: - 复杂 HTML

        DemoExample(
            id: "rich-text",
            title: "富文本综合",
            description: "多种样式组合",
            html: """
            <h2>公告</h2>
            <p>欢迎使用 <b>XMarkup</b> 解析引擎！</p>
            <p>支持 <i>斜体</i>、<u>下划线</u>、<s>删除线</s> 等格式。</p>
            <p>颜色：<span style="color:#FF0000">红色</span>、<span style="color:#00AA00">绿色</span>、<span style="color:#0000FF">蓝色</span>。</p>
            <p>访问 <a href="https://github.com">GitHub</a> 了解更多。</p>
            """,
            category: .complex
        ),
        DemoExample(
            id: "product-card",
            title: "商品卡片",
            description: "模拟电商商品信息",
            html: """
            <h3>iPhone 16 Pro</h3>
            <p><span style="color:#FF0000;font-size:24px"><b>¥8,999</b></span></p>
            <p>原价 <s>¥9,999</s>，立省 ¥1,000！</p>
            <p><span style="background-color:#FFFF00">限时优惠</span> 截止至 6 月 30 日</p>
            <p>详情请 <a href="https://example.com/product">点击查看</a></p>
            """,
            category: .complex
        ),
        DemoExample(
            id: "edge-cases",
            title: "边界情况",
            description: "空标签、嵌套、特殊字符",
            html: "空<b></b>标签 / 嵌套<b><i><u>三层</u></i></b> / <code>&lt;script&gt;</code> 转义",
            category: .complex
        ),

        // MARK: - 场景实战

        DemoExample(
            id: "article",
            title: "长文章阅读",
            description: "多段落、H1-H4、引用块、列表",
            html: """
            <h1>Swift 并发编程指南</h1>
            <p>Swift 5.5 引入了结构化并发，极大简化了异步编程模型。本文将从基础概念出发，逐步深入讲解 async/await、TaskGroup 和 Actor 的使用。</p>
            <h2>一、async/await 基础</h2>
            <p>传统的闭包回调容易导致<b>回调地狱</b>（Callback Hell），代码嵌套层次深、错误处理分散。async/await 让异步代码看起来像同步代码：</p>
            <p>使用 <code>async</code> 标记异步函数，用 <code>await</code> 挂起等待结果。编译器会在挂起点安全地让出线程，避免阻塞。</p>
            <h3>错误处理</h3>
            <p>配合 <code>do/catch</code> 语句，可以像处理同步错误一样处理异步错误：</p>
            <blockquote>结构化并发的核心思想是：每个并发任务都有明确的生命周期和作用域，编译器帮你保证资源不泄漏。</blockquote>
            <h2>二、Task 与 TaskGroup</h2>
            <p><b>Task</b> 是并发任务的基本单元。你可以创建 <i>非结构化任务</i>（detached task）或使用 <b>TaskGroup</b> 进行结构化并发：</p>
            <h4>子章节示例</h4>
            <p>TaskGroup 会自动等待所有子任务完成，并在任一子任务抛出错误时取消其余任务。</p>
            """,
            category: .scenario
        ),
        DemoExample(
            id: "chat-msg",
            title: "聊天消息",
            description: "@提及、紧凑排版、emoji、图片混排",
            html: """
            <p><b>张三</b> <span style="color:#999999;font-size:12px">14:32</span></p>
            <p>@李明 你看了昨天的发布会吗？<a href="https://example.com/live">直播回放</a>在这里 👀</p>
            <p>新功能简直<b>太棒了</b>！特别是那个实时协作编辑 ✨</p>
            <p><img src="https://example.com/screenshot.png"></p>
            <p><span style="color:#0088CC">@王芳</span> 你觉得这个设计怎么样？</p>
            <p><i>（消息已编辑）</i></p>
            """,
            category: .scenario
        ),
        DemoExample(
            id: "notification",
            title: "系统通知",
            description: "标题 + 富文本正文 + 操作链接",
            html: """
            <h3><span style="color:#FF6600">⚠️</span> 系统维护通知</h3>
            <p>尊敬的用户，我们将于 <b><span style="color:#FF0000">2026 年 6 月 15 日 02:00-06:00</span></b> 期间进行系统升级维护。</p>
            <p>维护期间以下服务将<u>暂时不可用</u>：</p>
            <p>• 在线支付功能</p>
            <p>• 数据导出服务</p>
            <p>• API 接口调用</p>
            <p>给您带来的不便，敬请谅解。如有疑问请联系 <a href="https://example.com/support"><span style="color:#0066CC">在线客服</span></a>。</p>
            <p><span style="color:#999999;font-size:12px">— 运维团队 · 2026-06-08</span></p>
            """,
            category: .scenario
        ),
        DemoExample(
            id: "api-doc",
            title: "代码文档",
            description: "标题、代码块、行内代码、参数说明",
            html: """
            <h2>XMarkupParser.parse(_:)</h2>
            <p>解析 HTML 字符串并返回结构化结果。</p>
            <h3>声明</h3>
            <p><code>public func parse(_ html: String) throws -&gt; XMarkupResult</code></p>
            <h3>参数</h3>
            <p><b>html</b> — HTML 输入字符串（UTF-8 编码）</p>
            <h3>返回值</h3>
            <p><code>XMarkupResult</code> — 包含解析后的纯文本和样式区间数组。</p>
            <h3>讨论</h3>
            <p>执行完整解析管线：<i>词法分析 → AST 构建 → 样式解析 → 实体解码 → UTF-16 索引映射</i>。</p>
            <p>线程安全：不同实例可跨线程并发使用，同一实例<b>不可并发调用</b>。</p>
            <h3>示例</h3>
            <p><code>let parser = try XMarkupParser()</code></p>
            <p><code>let result = try parser.parse("&lt;b&gt;Hello&lt;/b&gt;")</code></p>
            """,
            category: .scenario
        ),
        DemoExample(
            id: "social-post",
            title: "社交动态",
            description: "#话题、@用户、图片混排",
            html: """
            <p><b>技术探索者</b> <span style="color:#999999">· 2 小时前</span></p>
            <p>今天终于搞定了 XMarkup 的 C++ 核心引擎 🎉 踩了不少坑：</p>
            <p>1. UTF-8 和 UTF-16 索引转换比想象中复杂得多</p>
            <p>2. HTML 实体解码需要处理 <code>&amp;amp;</code> 这种嵌套转义</p>
            <p>3. 空白折叠规则要考虑 <code>&lt;pre&gt;</code> 标签的特殊情况</p>
            <p><img src="https://example.com/code-screenshot.png"></p>
            <p><span style="color:#0066CC">#Swift开发</span> <span style="color:#0066CC">#C++</span> <span style="color:#0066CC">#富文本解析</span></p>
            <p><a href="https://example.com/user/claude"><span style="color:#0088CC">@Claude</span></a> 感谢 AI 辅助编程的帮助！</p>
            <p><span style="color:#999999;font-size:12px">❤️ 128 · 💬 32 · 🔄 56</span></p>
            """,
            category: .scenario
        ),
        DemoExample(
            id: "product-detail",
            title: "商品详情",
            description: "价格、规格表、促销标签、图片",
            html: """
            <h2>MacBook Pro 16 英寸</h2>
            <p><span style="color:#FF0000;font-size:28px"><b>¥19,999</b></span> <s>¥22,999</s> <span style="background-color:#FF4444;color:#FFFFFF"> 省 ¥3,000 </span></p>
            <p><img src="https://example.com/macbook-pro.png"></p>
            <h3>核心规格</h3>
            <p>• 芯片：<b>Apple M4 Pro</b>（14 核 CPU / 20 核 GPU）</p>
            <p>• 内存：<span style="color:#FF6600"><b>48GB</b></span> 统一内存</p>
            <p>• 存储：1TB SSD（最高可选 8TB）</p>
            <p>• 显示屏：16.2 英寸 Liquid Retina XDR</p>
            <p>• 电池：最长 <mark>22 小时</mark> 续航</p>
            <p><span style="background-color:#FFF3CD">🎁 教育优惠额外减 ¥2,000</span></p>
            <p>详细信息请 <a href="https://example.com/macbook-pro">查看完整规格</a></p>
            """,
            category: .scenario
        ),

        // MARK: - 媒体

        DemoExample(
            id: "media-mix",
            title: "图文音视频混排",
            description: "img + video + audio + 文字组合",
            html: """
            <h2>2026 年度旅行 vlog</h2>
            <p>这次旅行从<b>东京</b>出发，途径 <i>京都</i>、<i>大阪</i>，最终抵达<b>北海道</b>。以下是精彩瞬间 🎬</p>
            <h3>📷 富士山日出</h3>
            <p><img src="https://example.com/fuji-sunrise.jpg"></p>
            <p>凌晨 4 点出发，等了两个小时终于拍到了这张 <span style="color:#FF6600">金色日出</span>。</p>
            <h3>🎥 京都岚山竹林</h3>
            <p><video src="https://example.com/bamboo-forest.mp4"></video></p>
            <p>竹林中的光影变幻，视频比照片更能传达那种宁静感。</p>
            <h3>🎵 街头艺人演奏</h3>
            <p><audio src="https://example.com/street-music.mp3"></audio></p>
            <p>在<b>心斋桥</b>遇到的街头艺人，<span style="color:#9B59B6">萨克斯</span>吹得真好听。</p>
            <p>—— 全程使用 iPhone 拍摄，<a href="https://example.com/gear">拍摄器材清单</a></p>
            """,
            category: .media
        ),

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
    ]
}
