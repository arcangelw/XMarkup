import Foundation

/// 标题与段落族 — h1-h6 / p / br / hr
enum HeadingParagraphExamples {
    static let all: [DemoExample] = [
        DemoExample(id: "headings", title: "H1 ~ H6 标题", summary: "各级标题缩放对比",
            html: "<h1>一级标题 H1</h1><h2>二级标题 H2</h2><h3>三级标题 H3</h3><h4>四级标题 H4</h4><h5>五级标题 H5</h5><h6>六级标题 H6</h6><p>正文段落，对比标题大小。</p>",
            family: .headingParagraph, tier: .basic),
        DemoExample(id: "heading-with-inline", title: "标题内嵌样式", summary: "标题内含粗体/斜体/代码/链接",
            html: """
            <h1>标题含<code>代码</code>和<i>斜体</i></h1>
            <h2>标题含<a href="https://swift.org">链接</a>和<mark>高亮</mark></h2>
            <h3>标题含<span style="color:#FF0000">红色</span>和<b>粗体</b></h3>
            """,
            family: .headingParagraph, tier: .nested),
        DemoExample(id: "hr-br", title: "水平线与换行", summary: "<hr> / <br> void 元素",
            html: "<p>第一行<br>第二行<br>第三行</p><hr><p>水平线分隔后的段落。</p>",
            family: .headingParagraph, tier: .basic),
    ]
}
