import Foundation
import XMarkup

/// 预设 HTML 示例
struct DemoExample: Identifiable {
    let id: String
    let title: String
    let description: String
    let html: String
    let category: Category
    let customTheme: MarkupTheme?
    let secondHTML: String?

    init(id: String, title: String, description: String, html: String, category: Category) {
        self.id = id
        self.title = title
        self.description = description
        self.html = html
        self.category = category
        self.customTheme = nil
        self.secondHTML = nil
    }

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
        case list = "列表"
        case mixed = "混合样式"
        case complex = "复杂 HTML"
        case scenario = "场景实战"
        case media = "媒体"
        case semantic = "语义标签"
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
            description: "<b> / <strong> 标签",
            html: "这是<b>粗体</b>文字示例，<strong>strong 标签</strong>也表示加粗。",
            category: .basic
        ),
        DemoExample(
            id: "italic",
            title: "斜体",
            description: "<i> / <em> 标签",
            html: "这是<i>斜体</i>文字示例，<em>em 标签</em>也表示强调。",
            category: .basic
        ),
        DemoExample(
            id: "underline",
            title: "下划线",
            description: "<u> 标签",
            html: "这是<u>下划线</u>文字示例，常用于<u>重要术语</u>标注。",
            category: .basic
        ),
        DemoExample(
            id: "strikethrough",
            title: "删除线",
            description: "<s> / <del> / <strike> 标签",
            html: "这是<s>删除线</s>文字，原价 <del>¥199</del> 现价 ¥99，旧版 <strike>已废弃</strike>。",
            category: .basic
        ),
        DemoExample(
            id: "sub-sup",
            title: "上标与下标",
            description: "<sub> / <sup> 标签",
            html: "化学公式 H<sub>2</sub>O、CO<sub>2</sub>，数学表达 x<sup>2</sup> + y<sup>3</sup> = z<sup>n</sup>，脚注<sup>[1]</sup>。",
            category: .basic
        ),
        DemoExample(
            id: "bold-italic",
            title: "粗体 + 斜体",
            description: "嵌套样式合并",
            html: "这是<b><i>粗斜体</i></b>文字，展示<b>嵌套<i>组合</i></b>效果。再来一个<i><b>反向嵌套</b></i>。",
            category: .basic
        ),

        // MARK: - 颜色

        DemoExample(
            id: "text-color",
            title: "文字颜色",
            description: "style=\"color:#RRGGBB\"",
            html: """
            <span style="color:#FF0000">红色</span>、<span style="color:#FF6600">橙色</span>、\
            <span style="color:#FFAA00">黄色</span>、<span style="color:#00AA00">绿色</span>、\
            <span style="color:#0066FF">蓝色</span>、<span style="color:#9900CC">紫色</span> 文字。
            """,
            category: .color
        ),
        DemoExample(
            id: "bg-color",
            title: "背景颜色",
            description: "style=\"background-color:#RRGGBB\"",
            html: """
            <span style="background-color:#FFFF00">黄色背景</span> / \
            <span style="background-color:#90EE90">绿色背景</span> / \
            <span style="background-color:#ADD8E6">蓝色背景</span> / \
            <span style="background-color:#FFB6C1">粉色背景</span> 的文字。
            """,
            category: .color
        ),
        DemoExample(
            id: "combined-color",
            title: "前景色 + 背景色",
            description: "同时指定 color 和 background-color",
            html: """
            <span style="color:#FFFFFF;background-color:#333333"> 白字灰底 </span> \
            <span style="color:#000000;background-color:#FFD700"> 黑字金底 </span> \
            <span style="color:#FFFFFF;background-color:#FF4444"> 白字红底 </span> \
            <span style="color:#00FF00;background-color:#000000"> 绿字黑底 </span>
            """,
            category: .color
        ),
        DemoExample(
            id: "color-named",
            title: "CSS 命名颜色",
            description: "color:red / blue / green 等",
            html: """
            <span style="color:red">red</span>、<span style="color:blue">blue</span>、\
            <span style="color:green">green</span>、<span style="color:orange">orange</span>、\
            <span style="color:purple">purple</span>、<span style="color:teal">teal</span>。
            """,
            category: .color
        ),
        DemoExample(
            id: "color-rgb",
            title: "RGB 函数颜色",
            description: "color:rgb(r,g,b) 格式",
            html: """
            <span style="color:rgb(255,0,0)">RGB 红色</span>、\
            <span style="color:rgb(0,128,255)">RGB 蓝色</span>、\
            <span style="color:rgb( 128 , 0 , 255 )">RGB 紫色（含空格）</span>。
            """,
            category: .color
        ),

        // MARK: - 标题

        DemoExample(
            id: "headings",
            title: "H1 ~ H6 标题",
            description: "各级标题缩放对比",
            html: "<h1>一级标题 H1</h1><h2>二级标题 H2</h2><h3>三级标题 H3</h3><h4>四级标题 H4</h4><h5>五级标题 H5</h5><h6>六级标题 H6</h6><p>正文段落，对比标题大小。</p>",
            category: .heading
        ),
        DemoExample(
            id: "heading-with-inline",
            title: "标题内嵌样式",
            description: "标题内包含粗体、斜体、代码、链接",
            html: """
            <h1>标题含<code>代码</code>和<i>斜体</i></h1>
            <h2>标题含<a href="https://swift.org">链接</a>和<mark>高亮</mark></h2>
            <h3>标题含<span style="color:#FF0000">红色</span>和<b>粗体</b></h3>
            """,
            category: .heading
        ),

        // MARK: - 链接

        DemoExample(
            id: "link",
            title: "超链接",
            description: "<a href=\"...\"> 标签",
            html: "访问 <a href=\"https://github.com\">GitHub</a>、<a href=\"https://swift.org\">Swift 官网</a>、<a href=\"https://developer.apple.com\">Apple Developer</a>。",
            category: .link
        ),
        DemoExample(
            id: "link-styled",
            title: "带样式的链接",
            description: "链接 + 颜色 + 粗体组合",
            html: """
            点击 <a href="https://example.com"><span style="color:#FF6600"><b>橙色粗体链接</b></span></a>，\
            或者 <a href="https://example.com"><i>斜体链接</i></a>，\
            还有 <a href="https://example.com"><span style="color:#9900CC">紫色链接</span></a>。
            """,
            category: .link
        ),

        // MARK: - 列表

        DemoExample(
            id: "list-unordered",
            title: "无序列表",
            description: "<ul><li> 标签",
            html: """
            <ul>
            <li>Swift 编程语言</li>
            <li>Objective-C 运行时</li>
            <li>C++ 核心引擎</li>
            </ul>
            """,
            category: .list
        ),
        DemoExample(
            id: "list-ordered",
            title: "有序列表",
            description: "<ol><li> 标签",
            html: """
            <ol>
            <li>创建解析器实例</li>
            <li>调用 parse() 方法</li>
            <li>构建 MarkupDocument</li>
            <li>渲染为 AttributedString</li>
            </ol>
            """,
            category: .list
        ),
        DemoExample(
            id: "list-nested",
            title: "嵌套列表",
            description: "ol 内嵌 ul，验证 isOrdered 判定",
            html: """
            <ol>
            <li>前端技术
            <ul>
            <li>HTML / CSS</li>
            <li>JavaScript / TypeScript</li>
            </ul>
            </li>
            <li>后端技术
            <ul>
            <li>Node.js</li>
            <li>Python / Django</li>
            </ul>
            </li>
            <li>移动开发
            <ol>
            <li>iOS (Swift)</li>
            <li>Android (Kotlin)</li>
            </ol>
            </li>
            </ol>
            """,
            category: .list
        ),

        // MARK: - 混合样式

        DemoExample(
            id: "font-size",
            title: "自定义字号",
            description: "px / em / % 单位",
            html: """
            默认字号 / <span style="font-size:24px">24px 大号</span> / <span style="font-size:10px">10px 小号</span> / \
            <span style="font-size:1.5em">1.5em 字号</span> / <span style="font-size:150%">150% 字号</span>。
            """,
            category: .mixed
        ),
        DemoExample(
            id: "code",
            title: "行内代码",
            description: "<code> 标签",
            html: "使用 <code>let parser = try XMarkupParser()</code> 创建解析器，调用 <code>parser.parse(html)</code> 解析 HTML。",
            category: .mixed
        ),
        DemoExample(
            id: "mark",
            title: "高亮标记",
            description: "<mark> 标签",
            html: "请重点阅读<mark>这段高亮内容</mark>，它是<mark>核心知识点</mark>。普通文字作为对照。",
            category: .mixed
        ),
        DemoExample(
            id: "pre",
            title: "预格式化文本",
            description: "<pre> 标签，保留空白和换行",
            html: """
            <p>以下是代码块：</p>
            <pre>func greet(name: String) {
                print("Hello, \\(name)!")
            }

            greet(name: "XMarkup")</pre>
            <p>代码块结束。</p>
            """,
            category: .mixed
        ),
        DemoExample(
            id: "blockquote",
            title: "引用块",
            description: "<blockquote> 标签",
            html: """
            <p>有人说过：</p>
            <blockquote>任何足够先进的技术，都与魔法无异。—— Arthur C. Clarke</blockquote>
            <p>这句话在编程领域同样适用。</p>
            """,
            category: .mixed
        ),

        // MARK: - 复杂 HTML

        DemoExample(
            id: "rich-text",
            title: "富文本综合",
            description: "标题 + 段落 + 列表 + 引用 + 代码 + 链接",
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
            category: .complex
        ),
        DemoExample(
            id: "product-card",
            title: "商品卡片",
            description: "电商商品信息卡片",
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
            category: .complex
        ),
        DemoExample(
            id: "table-layout",
            title: "表格布局",
            description: "<table> + <tr> + <td> + <th>",
            html: """
            <h3>编程语言对比</h3>
            <table>
            <tr><th>语言</th><th>类型</th><th>特点</th></tr>
            <tr><td>Swift</td><td>编译型</td><td>安全、快速、现代</td></tr>
            <tr><td>Kotlin</td><td>编译型</td><td>简洁、互操作性强</td></tr>
            <tr><td>Python</td><td>解释型</td><td>简单易学、生态丰富</td></tr>
            <tr><td>Rust</td><td>编译型</td><td>零成本抽象、内存安全</td></tr>
            </table>
            """,
            category: .complex
        ),
        DemoExample(
            id: "edge-cases",
            title: "边界情况",
            description: "空标签、深嵌套、转义字符",
            html: "空<b></b>标签 / 嵌套<b><i><u><s>四层样式</s></u></i></b> / <code>&lt;script&gt;</code> 转义 / HTML 实体 &amp; &lt; &gt; &quot;",
            category: .complex
        ),

        // MARK: - 场景实战

        DemoExample(
            id: "article",
            title: "技术文章",
            description: "多段落、多级标题、引用、代码、列表",
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
            category: .scenario
        ),
        DemoExample(
            id: "chat-msg",
            title: "聊天消息",
            description: "@提及、emoji、时间戳、图片",
            html: """
            <p><b>张三</b> <span style="color:#999999;font-size:12px">14:32</span></p>
            <p>@李明 你看了昨天的发布会吗？<a href="https://developer.apple.com/wwdc/">直播回放</a>在这里 👀</p>
            <p>新功能简直<b>太棒了</b>！特别是那个实时协作编辑 ✨</p>
            <p><img src="https://images.unsplash.com/photo-1517694712202-14dd9538aa97?w=300"></p>
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
            <ul>
            <li>在线支付功能</li>
            <li>数据导出服务</li>
            <li>API 接口调用</li>
            </ul>
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
            category: .scenario
        ),
        DemoExample(
            id: "social-post",
            title: "社交动态",
            description: "#话题、@用户、图片、互动数据",
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
            category: .scenario
        ),
        DemoExample(
            id: "product-detail",
            title: "商品详情",
            description: "价格、规格、促销、图片",
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
            category: .scenario
        ),

        // MARK: - 媒体

        DemoExample(
            id: "image-single",
            title: "单张图片",
            description: "<img src=\"...\"> 标签",
            html: """
            <h3>富士山日出</h3>
            <p><img src="https://images.unsplash.com/photo-1490806843957-31f4c9a91c65?w=600"></p>
            <p>凌晨 4 点出发，等了两个小时终于拍到了这张 <span style="color:#FF6600">金色日出</span>。</p>
            """,
            category: .media
        ),
        DemoExample(
            id: "video-single",
            title: "视频",
            description: "<video src=\"...\"> 标签",
            html: """
            <h3>🎥 Big Buck Bunny 片段</h3>
            <p><video src="https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"></video></p>
            <p>这是一段开源动画短片，常用于视频播放器测试。</p>
            """,
            category: .media
        ),
        DemoExample(
            id: "video-source",
            title: "视频（source 子标签）",
            description: "<video><source src=\"...\" type=\"...\">",
            html: """
            <h3>🎬 Elephant's Dream</h3>
            <video><source src="https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4" type="video/mp4"></video>
            <p>开源动画项目 <i>Elephant's Dream</i>，由 Blender 基金会制作。</p>
            """,
            category: .media
        ),
        DemoExample(
            id: "audio-single",
            title: "音频",
            description: "<audio src=\"...\"> 标签",
            html: """
            <h3>🎵 示例音频</h3>
            <p><audio src="https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3"></audio></p>
            <p>SoundHelix 提供的免费示例音乐，适合测试音频渲染占位符。</p>
            """,
            category: .media
        ),
        DemoExample(
            id: "media-mix",
            title: "图文音视频混排",
            description: "img + video + audio + 文字组合",
            html: """
            <h2>2026 年度旅行 Vlog</h2>
            <p>这次旅行从<b>东京</b>出发，途径 <i>京都</i>、<i>大阪</i>，最终抵达<b>北海道</b>。以下是精彩瞬间 🎬</p>
            <h3>📷 富士山全景</h3>
            <p><img src="https://images.unsplash.com/photo-1490806843957-31f4c9a91c65?w=600"></p>
            <p>凌晨 4 点出发，等了两个小时终于拍到了这张 <span style="color:#FF6600">金色日出</span>。</p>
            <h3>🎥 街头风景</h3>
            <p><video src="https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4"></video></p>
            <p>城市街头的光影变幻，视频比照片更能传达那种宁静感。</p>
            <h3>🎵 街头艺人演奏</h3>
            <p><audio src="https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3"></audio></p>
            <p>在<b>心斋桥</b>遇到的街头艺人，<span style="color:#9B59B6">萨克斯</span>吹得真好听。</p>
            <p>—— 全程使用 iPhone 拍摄，<a href="https://www.apple.com/iphone/">拍摄器材清单</a></p>
            """,
            category: .media
        ),

        // MARK: - 语义标签

        DemoExample(
            id: "semantic-article",
            title: "article / section",
            description: "语义化文档结构",
            html: """
            <article>
            <header><h2>文章标题</h2><p><span style="color:#999999;font-size:12px">作者：张三 · 2026-06-09</span></p></header>
            <section><h3>第一章</h3><p>这是第一章的内容，使用 <code>&lt;section&gt;</code> 标签划分章节。</p></section>
            <section><h3>第二章</h3><p>这是第二章的内容，每个 section 都是独立的内容块。</p></section>
            <footer><p><span style="color:#999999;font-size:12px">© 2026 XMarkup Demo</span></p></footer>
            </article>
            """,
            category: .semantic
        ),
        DemoExample(
            id: "semantic-nav-aside",
            title: "nav / aside / main",
            description: "导航、侧边栏、主内容区",
            html: """
            <nav><p><b>导航栏：</b><a href="#home">首页</a> | <a href="#about">关于</a> | <a href="#contact">联系</a></p></nav>
            <main>
            <h2>主内容区域</h2>
            <p>这里是页面的主要内容，使用 <code>&lt;main&gt;</code> 标签标识。</p>
            </main>
            <aside><p><i>侧边栏：相关推荐内容放在 <code>&lt;aside&gt;</code> 标签中。</i></p></aside>
            """,
            category: .semantic
        ),
        DemoExample(
            id: "semantic-figure",
            title: "figure / figcaption",
            description: "图文组及其标题",
            html: """
            <figure>
            <img src="https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=400">
            <figcaption><span style="color:#666666;font-size:12px">图 1：优胜美地国家公园，摄于 2026 年春季。</span></figcaption>
            </figure>
            <p>上图展示了 <code>&lt;figure&gt;</code> 和 <code>&lt;figcaption&gt;</code> 标签的用法。</p>
            """,
            category: .semantic
        ),
        DemoExample(
            id: "semantic-dl",
            title: "定义列表",
            description: "<dl> / <dt> / <dd> 标签",
            html: """
            <h3>XMarkup 术语表</h3>
            <dl>
            <dt><b>Span</b></dt>
            <dd>样式区间，描述一段文本上的标签类型和 CSS 样式属性。</dd>
            <dt><b>MarkupDocument</b></dt>
            <dd>结构化文档模型，由多个 MarkupBlock 组成。</dd>
            <dt><b>Theme</b></dt>
            <dd>渲染主题，控制字体、颜色、间距等视觉属性。</dd>
            </dl>
            """,
            category: .semantic
        ),
        DemoExample(
            id: "semantic-address",
            title: "address 标签",
            description: "联系信息",
            html: """
            <h3>联系我们</h3>
            <address>
            <p><b>XMarkup 开源团队</b></p>
            <p>邮箱：<a href="mailto:dev@example.com">dev@example.com</a></p>
            <p>GitHub：<a href="https://github.com">github.com/xmarkup</a></p>
            </address>
            """,
            category: .semantic
        ),

        // MARK: - 边界用例

        DemoExample(
            id: "emoji-only",
            title: "纯 Emoji",
            description: "仅包含 Emoji 字符",
            html: "🔄❤️🎉✨👀💬🔥💡🚀🌈🎭🦋",
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
            description: "多语言 + Emoji + 组合字符",
            html: "مرحبا 你好 こんにちは 안녕하세요 🌍 Héllo wörld 🇨🇳🇯🇵🇺🇸 👨‍👩‍👧‍👦",
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
            html: "常用实体：&amp; &lt; &gt; &quot; &#x1F600; 还有一些特殊字符：© ® ™ — …",
            category: .boundary
        ),
        DemoExample(
            id: "unclosed-tags",
            title: "未闭合标签",
            description: "自动纠错容错能力",
            html: "<b>未闭合的粗体 <i>未闭合的斜体 <p>跨段落的标签</p> 后续文字",
            category: .boundary
        ),
        DemoExample(
            id: "hr-br",
            title: "水平线与换行",
            description: "<hr> / <br> void 元素",
            html: "<p>第一行<br>第二行<br>第三行</p><hr><p>水平线分隔后的段落。</p>",
            category: .boundary
        ),

        // MARK: - 段落排版

        DemoExample(
            id: "spacing-default",
            title: "默认间距",
            description: "ParagraphSpacing(8, 8, 0)",
            html: """
            <p>第一段：使用默认段落间距（段前 8pt、段后 8pt、行距 0）。</p>
            <p>第二段：注意观察段落之间的间距。合理的段落间距能显著提升阅读体验。</p>
            <p>第三段：每个 <code>&lt;p&gt;</code> 标签对应一个独立的段落 block。</p>
            <p>第四段：通过对比其他间距示例，可以直观感受不同配置的效果。</p>
            <h3>标题也参与段落间距</h3>
            <p>标题下方的第五段文字。</p>
            """,
            category: .spacing,
            customTheme: .default
        ),
        DemoExample(
            id: "spacing-compact",
            title: "紧凑排版",
            description: "ParagraphSpacing(2, 2, 0)",
            html: """
            <p>第一段：使用紧凑段落间距（段前 2pt、段后 2pt、行距 0）。</p>
            <p>第二段：紧凑排版适合信息密度高的场景，如列表、数据展示。</p>
            <p>第三段：段落之间几乎没有额外空白。</p>
            <p>第四段：紧凑排版可让更多内容在有限空间内展示。</p>
            <h3>紧凑标题</h3>
            <p>标题下方的第五段文字。</p>
            """,
            category: .spacing,
            customTheme: .spacingCompact
        ),
        DemoExample(
            id: "spacing-relaxed",
            title: "宽松排版 + 行距",
            description: "ParagraphSpacing(16, 16, 6)",
            html: """
            <p>第一段：使用宽松段落间距（段前 16pt、段后 16pt、行距 6pt）。</p>
            <p>第二段：宽松排版适合长文阅读场景，给眼睛更多呼吸空间。</p>
            <p>第三段：额外的行间距让每行文字更加清晰可辨。</p>
            <p>第四段：适合文章、书籍等需要舒适阅读体验的场景。</p>
            <h3>宽松标题</h3>
            <p>标题下方的第五段文字。</p>
            """,
            category: .spacing,
            customTheme: .spacingRelaxed
        ),
        DemoExample(
            id: "spacing-none",
            title: "零间距",
            description: "ParagraphSpacing(0, 0, 0)",
            html: """
            <p>第一段：使用零间距（段前 0pt、段后 0pt、行距 0pt）。</p>
            <p>第二段：段落之间没有任何额外间距，紧密相连。</p>
            <p>第三段：适用于需要精确控制排版的特殊场景。</p>
            <p>第四段：零间距让所有内容挤在一起。</p>
            <h3>零间距标题</h3>
            <p>标题下方的第五段文字。</p>
            """,
            category: .spacing,
            customTheme: .spacingNone
        ),

        // MARK: - 长内容

        DemoExample(
            id: "long-article",
            title: "完整技术文章",
            description: "~1200 字，多级标题、引用、代码、列表、链接",
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
            category: .longform
        ),
        DemoExample(
            id: "gallery",
            title: "多媒体图文长页",
            description: "多张真实图片 + 文字描述 + 视频",
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
