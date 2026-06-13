import Foundation

/// 语义容器族 — div / article / section / nav / aside / header / footer / address
enum SemanticExamples {
    static let all: [DemoExample] = [
        DemoExample(id: "semantic-article", title: "article / section", summary: "语义化文档结构",
            html: """
            <article>
            <header><h2>文章标题</h2><p><span style="color:#999999;font-size:12px">作者：张三 · 2026-06-09</span></p></header>
            <section><h3>第一章</h3><p>这是第一章的内容，使用 <code>&lt;section&gt;</code> 标签划分章节。</p></section>
            <section><h3>第二章</h3><p>这是第二章的内容，每个 section 都是独立的内容块。</p></section>
            <footer><p><span style="color:#999999;font-size:12px">© 2026 XMarkup Demo</span></p></footer>
            </article>
            """,
            family: .semantic, tier: .basic),
        DemoExample(id: "semantic-nav-aside", title: "nav / aside / main", summary: "导航、侧边栏、主内容区",
            html: """
            <nav><p><b>导航栏：</b><a href="#home">首页</a> | <a href="#about">关于</a> | <a href="#contact">联系</a></p></nav>
            <main>
            <h2>主内容区域</h2>
            <p>这里是页面的主要内容，使用 <code>&lt;main&gt;</code> 标签标识。</p>
            </main>
            <aside><p><i>侧边栏：相关推荐内容放在 <code>&lt;aside&gt;</code> 标签中。</i></p></aside>
            """,
            family: .semantic, tier: .basic),
        DemoExample(id: "semantic-figure", title: "figure / figcaption", summary: "图文组及其标题",
            html: """
            <figure>
            <img src="https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=400">
            <figcaption><span style="color:#666666;font-size:12px">图 1：优胜美地国家公园，摄于 2026 年春季。</span></figcaption>
            </figure>
            <p>上图展示了 <code>&lt;figure&gt;</code> 和 <code>&lt;figcaption&gt;</code> 标签的用法。</p>
            """,
            family: .semantic, tier: .nested),
        DemoExample(id: "semantic-dl", title: "定义列表", summary: "<dl> / <dt> / <dd> 标签",
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
            family: .semantic, tier: .nested),
        DemoExample(id: "semantic-address", title: "address 标签", summary: "联系信息",
            html: """
            <h3>联系我们</h3>
            <address>
            <p><b>XMarkup 开源团队</b></p>
            <p>邮箱：<a href="mailto:dev@example.com">dev@example.com</a></p>
            <p>GitHub：<a href="https://github.com">github.com/xmarkup</a></p>
            </address>
            """,
            family: .semantic, tier: .nested),
    ]
}
