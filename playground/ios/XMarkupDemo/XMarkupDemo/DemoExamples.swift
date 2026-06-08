import Foundation

/// 预设 HTML 示例
struct DemoExample: Identifiable {
    let id: String
    let title: String
    let description: String
    let html: String
    let category: Category

    enum Category: String, CaseIterable {
        case basic = "基础格式"
        case color = "颜色"
        case heading = "标题"
        case link = "链接"
        case mixed = "混合样式"
        case complex = "复杂 HTML"
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
    ]
}
