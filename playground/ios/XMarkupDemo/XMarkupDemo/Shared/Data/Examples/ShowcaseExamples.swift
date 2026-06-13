import Foundation

/// 综合实战族 — 长文 / 复杂结构 / 真实场景
enum ShowcaseExamples {
    static let all: [DemoExample] = [
        DemoExample(id: "rich-text", title: "富文本综合", summary: "标题+段落+列表+引用+代码+链接",
            html: """
            <h2>XMarkup 功能概览</h2>
            <p>欢迎使用 <b>XMarkup</b> 解析引擎！它支持丰富的 HTML 格式化标签。</p>
            <h3>文本样式</h3>
            <p>支持 <b>粗体</b>、<i>斜体</i>、<u>下划线</u>、<s>删除线</s>、<code>行内代码</code>、<mark>高亮</mark>等格式。</p>
            <h3>颜色支持</h3>
            <p>前景色：<span style="color:#FF0000">红色</span>、<span style="color:#00AA00">绿色</span>、<span style="color:#0000FF">蓝色</span>。</p>
            <p>背景色：<span style="background-color:#FFFF00">黄色高亮</span>、<span style="background-color:#90EE90">绿色高亮</span>。</p>
            <blockquote>XMarkup 使用 C++ 核心引擎，通过 Swift 桥接层提供原生 API。</blockquote>
            <p>详情请访问 <a href="https://github.com">GitHub 仓库</a>。</p>
            """,
            family: .showcase, tier: .nested),
        DemoExample(id: "product-card", title: "商品卡片", summary: "电商商品信息卡片",
            html: """
            <h3>iPhone 16 Pro Max</h3>
            <p><span style="color:#FF0000;font-size:28px"><b>¥9,999</b></span> <s>¥11,999</s> <span style="background-color:#FF4444;color:#FFFFFF"> 限时直降 ¥2,000 </span></p>
            <p><img src="https://images.unsplash.com/photo-1695048133142-1a20484d2569?w=400"></p>
            <h4>核心配置</h4>
            <p>• 芯片：<b>Apple A18 Pro</b>（6 核 CPU / 6 核 GPU）</p>
            <p>• 内存：<span style="color:#FF6600"><b>8GB</b></span> 运行内存</p>
            <p>• 存储：256GB / 512GB / 1TB</p>
            <p>• 屏幕：6.9 英寸 Super Retina XDR</p>
            <p>• 电池：最长 <mark>33 小时</mark> 视频播放</p>
            <p><span style="background-color:#FFF3CD">🎁 教育优惠额外减 ¥800</span></p>
            <p>了解更多请 <a href="https://www.apple.com/shop/buy-iphone">前往 Apple Store</a></p>
            """,
            family: .showcase, tier: .nested),
        DemoExample(id: "edge-cases", title: "边界情况", summary: "空标签、深嵌套、转义字符",
            html: "空<b></b>标签 / 嵌套<b><i><u><s>四层样式</s></u></i></b> / <code>&lt;script&gt;</code> 转义 / HTML 实体 &amp; &lt; &gt; &quot;",
            family: .showcase, tier: .boundary, isRegression: true,
            note: "空标签 + 深嵌套 + 实体转义综合"),
        DemoExample(id: "article", title: "技术文章", summary: "多段落、多级标题、引用、代码、列表",
            html: """
            <h1>Swift 并发编程指南</h1>
            <p>Swift 5.5 引入了结构化并发，极大简化了异步编程模型。本文将从基础概念出发，逐步深入讲解 async/await、TaskGroup 和 Actor 的使用。</p>
            <h2>一、async/await 基础</h2>
            <p>传统的闭包回调容易导致<b>回调地狱</b>（Callback Hell），代码嵌套层次深、错误处理分散。<code>async/await</code> 让异步代码看起来像同步代码：</p>
            <p>使用 <code>async</code> 标记异步函数，用 <code>await</code> 挂起等待结果。编译器会在挂起点安全地让出线程，避免阻塞。</p>
            <h3>错误处理</h3>
            <p>配合 <code>do/catch</code> 语句，可以像处理同步错误一样处理异步错误。</p>
            <blockquote>结构化并发的核心思想是：每个并发任务都有明确的生命周期和作用域，编译器帮你保证资源不泄漏。</blockquote>
            <h2>二、Task 与 TaskGroup</h2>
            <p><b>Task</b> 是并发任务的基本单元。你可以创建 <i>非结构化任务</i>（detached task）或使用 <b>TaskGroup</b> 进行结构化并发。</p>
            <p>TaskGroup 会自动等待所有子任务完成，并在任一子任务抛出错误时取消其余任务。</p>
            <h2>三、Actor 模型</h2>
            <p><code>actor</code> 关键字定义了一个引用类型，它的所有存储属性都自动受到数据隔离保护。外部访问 actor 的属性或方法时，必须使用 <code>await</code>：</p>
            <ul>
            <li>Actor 保证<b>串行访问</b>：同一时刻只有一个任务能访问 actor 的内部状态</li>
            <li>编译器在编译期检查数据竞争，而非留到运行时</li>
            <li><code>@MainActor</code> 是一个全局 actor，代表主线程</li>
            </ul>
            <p>更多内容请参阅 <a href="https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/">Swift 官方文档</a>。</p>
            """,
            family: .showcase, tier: .nested),
        DemoExample(id: "chat-msg", title: "聊天消息", summary: "@提及、emoji、时间戳、图片",
            html: """
            <p><b>张三</b> <span style="color:#999999;font-size:12px">14:32</span></p>
            <p>@李明 你看了昨天的发布会吗？<a href="https://developer.apple.com/wwdc/">直播回放</a>在这里 👀</p>
            <p>新功能简直<b>太棒了</b>！特别是那个实时协作编辑 ✨</p>
            <p><img src="https://images.unsplash.com/photo-1517694712202-14dd9538aa97?w=300"></p>
            <p><span style="color:#0088CC">@王芳</span> 你觉得这个设计怎么样？</p>
            <p><i>（消息已编辑）</i></p>
            """,
            family: .showcase, tier: .nested),
        DemoExample(id: "notification", title: "系统通知", summary: "标题 + 富文本正文 + 操作链接",
            html: """
            <h3><span style="color:#FF6600">⚠️</span> 系统维护通知</h3>
            <p>尊敬的用户，我们将于 <b><span style="color:#FF0000">2026 年 6 月 15 日 02:00-06:00</span></b> 期间进行系统升级维护。</p>
            <p>维护期间以下服务将<u>暂时不可用</u>：</p>
            <ul>
            <li>在线支付功能</li>
            <li>数据导出服务</li>
            <li>API 接口调用</li>
            </ul>
            <p>给您带来的不便，敬请谅解。如有疑问请联系 <a href="https://example.com/support"><span style="color:#0066CC">在线客服</span></a>。</p>
            <p><span style="color:#999999;font-size:12px">— 运维团队 · 2026-06-08</span></p>
            """,
            family: .showcase, tier: .nested),
        DemoExample(id: "api-doc", title: "代码文档", summary: "标题、代码块、行内代码、参数说明",
            html: """
            <h2>XMarkupParser.parse(_:)</h2>
            <p>解析 HTML 字符串并返回结构化结果。</p>
            <h3>声明</h3>
            <pre>public func parse(_ html: String) throws -> XMarkupResult</pre>
            <h3>参数</h3>
            <p><b>html</b> — HTML 输入字符串（UTF-8 编码）</p>
            <h3>返回值</h3>
            <p><code>XMarkupResult</code> — 包含解析后的纯文本和样式区间数组。</p>
            <h3>讨论</h3>
            <p>执行完整解析管线：<i>词法分析 → AST 构建 → 样式解析 → 实体解码 → UTF-16 索引映射</i>。</p>
            <p>线程安全：不同实例可跨线程并发使用，同一实例<b>不可并发调用</b>。</p>
            <h3>示例</h3>
            <pre>let parser = try XMarkupParser()
            let result = try parser.parse("&lt;b&gt;Hello&lt;/b&gt;")
            let doc = MarkupDocument.from(result)
            let attr = doc.render(theme: .default)</pre>
            """,
            family: .showcase, tier: .nested),
        DemoExample(id: "social-post", title: "社交动态", summary: "#话题、@用户、图片、互动数据",
            html: """
            <p><b>技术探索者</b> <span style="color:#999999">· 2 小时前</span></p>
            <p>今天终于搞定了 XMarkup 的 C++ 核心引擎 🎉 踩了不少坑：</p>
            <ol>
            <li>UTF-8 和 UTF-16 索引转换比想象中复杂得多</li>
            <li>HTML 实体解码需要处理 <code>&amp;amp;</code> 这种嵌套转义</li>
            <li>空白折叠规则要考虑 <code>&lt;pre&gt;</code> 标签的特殊情况</li>
            </ol>
            <p><img src="https://images.unsplash.com/photo-1555066931-4365d14bab8c?w=400"></p>
            <p><span style="color:#0066CC">#Swift开发</span> <span style="color:#0066CC">#C++</span> <span style="color:#0066CC">#富文本解析</span></p>
            <p><span style="color:#999999;font-size:12px">❤️ 128 · 💬 32 · 🔄 56</span></p>
            """,
            family: .showcase, tier: .nested),
        DemoExample(id: "product-detail", title: "商品详情", summary: "价格、规格、促销、图片",
            html: """
            <h2>MacBook Pro 16 英寸</h2>
            <p><span style="color:#FF0000;font-size:28px"><b>¥19,999</b></span> <s>¥22,999</s> <span style="background-color:#FF4444;color:#FFFFFF"> 省 ¥3,000 </span></p>
            <p><img src="https://images.unsplash.com/photo-1517336714731-489689fd1ca8?w=400"></p>
            <h3>核心规格</h3>
            <p>• 芯片：<b>Apple M4 Pro</b>（14 核 CPU / 20 核 GPU）</p>
            <p>• 内存：<span style="color:#FF6600"><b>48GB</b></span> 统一内存</p>
            <p>• 存储：1TB SSD（最高可选 8TB）</p>
            <p>• 显示屏：16.2 英寸 Liquid Retina XDR</p>
            <p>• 电池：最长 <mark>22 小时</mark> 续航</p>
            <p><span style="background-color:#FFF3CD">🎁 教育优惠额外减 ¥2,000</span></p>
            <p>详细信息请 <a href="https://www.apple.com/shop/buy-mac/macbook-pro">查看完整规格</a></p>
            """,
            family: .showcase, tier: .nested),
        DemoExample(id: "long-article", title: "完整技术文章", summary: "~1200 字，多级标题、引用、代码、列表、链接",
            html: """
            <h1>SwiftUI 性能优化完全指南</h1>
            <p>SwiftUI 作为 Apple 推出的声明式 UI 框架，在简化开发流程的同时，也带来了新的性能挑战。本文将从实际场景出发，系统讲解 SwiftUI 性能优化的核心策略。</p>
            <h2>一、视图重组与 diff 机制</h2>
            <p>SwiftUI 使用 <b>声明式 diff 算法</b> 来决定哪些视图需要更新。每次状态变化时，框架会重新求值 body 属性，并与前一次的结构进行对比。</p>
            <p>关键优化点在于减少 <i>不必要的视图重组</i>。当一个视图的输入没有变化时，它的 body 不应该被重新求值。</p>
            <blockquote>性能优化的第一原则：让 SwiftUI 只做必要的 diff。任何导致不必要 diff 的代码都是潜在的性能瓶颈。</blockquote>
            <h3>1.1 Equatable 优化</h3>
            <p>当视图的参数实现了 <code>Equatable</code> 协议时，SwiftUI 可以跳过不必要的 body 求值。</p>
            <h3>1.2 @Observable 与细粒度追踪</h3>
            <p>Swift 5.9 引入的 <code>@Observable</code> 宏实现了<b>属性级依赖追踪</b>。相比旧的 <code>ObservableObject</code>，它能更精确地定位哪些属性发生了变化。</p>
            <h2>二、列表性能优化</h2>
            <p><code>LazyVStack</code> 和 <code>LazyHStack</code> 是处理大量数据的关键。它们只渲染可见区域的内容，避免一次性创建所有视图。</p>
            <ul>
            <li>优先使用 <code>Identifiable</code> 协议而非 <code>ForEach(_, id:)</code> 闭包</li>
            <li>使用 <code>List</code> 时确保每个 row 的 id 稳定且唯一</li>
            <li>图片加载使用 <code>AsyncImage</code> 配合缓存策略</li>
            </ul>
            <h2>三、动画性能</h2>
            <p>SwiftUI 动画默认使用 <code>Core Animation</code>，在 GPU 上执行。使用 <code>drawingGroup()</code> 修饰符将复杂视图组合并为单个 Metal 绘制调用。</p>
            <p>更多详情请参考 <a href="https://developer.apple.com/videos/">WWDC 视频</a>。</p>
            """,
            family: .showcase, tier: .nested),
        DemoExample(id: "gallery", title: "多媒体图文长页", summary: "多张真实图片 + 文字描述 + 视频",
            html: """
            <h1>2026 夏日旅行相册</h1>
            <p>这次旅行横跨三个国家，用镜头记录了每一个难忘瞬间。</p>
            <h2>🇯🇵 日本 · 东京</h2>
            <p><img src="https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?w=600"></p>
            <p>东京塔的夜景令人震撼，整座城市被灯光点亮，宛如星河倒映在大地上。</p>
            <p><img src="https://images.unsplash.com/photo-1542051841857-5f90071e7989?w=600"></p>
            <p>涩谷十字路口，世界上最繁忙的人行横道。每次绿灯亮起，多达 3000 人同时穿越。</p>
            <h2>🇫🇷 法国 · 巴黎</h2>
            <p><img src="https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=600"></p>
            <p>从战神广场仰望埃菲尔铁塔，黄昏时分的金色光芒洒满整座塔身。</p>
            <p><img src="https://images.unsplash.com/photo-1499856871958-5b9627545d1a?w=600"></p>
            <p>卢浮宫前的玻璃金字塔，建筑大师贝聿铭的杰作。</p>
            <h2>🇮🇹 意大利 · 罗马</h2>
            <p><img src="https://images.unsplash.com/photo-1552832230-c0197dd311b5?w=600"></p>
            <p>罗马斗兽场，两千年历史的见证。</p>
            <h3>🎥 旅行视频精选</h3>
            <p><video src="https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4"></video></p>
            <p><i>全程使用 iPhone 16 Pro Max 拍摄，后期使用 <a href="https://www.adobe.com/products/premiere.html">Premiere Pro</a> 剪辑。</i></p>
            """,
            family: .showcase, tier: .nested),
    ]
}
