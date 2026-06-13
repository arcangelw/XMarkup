import Foundation

/// 内联文本族 — b/i/u/s/em/strong/sub/sup/code/mark（设计规格 §4.1）
enum InlineTextExamples {
    static let all: [DemoExample] = [
        DemoExample(id: "bold", title: "粗体", summary: "<b> / <strong>",
            html: "这是<b>粗体</b>文字示例，<strong>strong 标签</strong>也表示加粗。",
            family: .inlineText, tier: .basic),
        DemoExample(id: "italic", title: "斜体", summary: "<i> / <em>（英文原生 + 中文合成）",
            html: "English <i>italic</i> works natively. <em>Emphasized text</em> also renders as italic. 中文<i>斜体</i>使用合成倾斜。粗斜体：<b><i>bold italic</i></b> / <b><i>中文粗斜</i></b>。",
            family: .inlineText, tier: .basic),
        DemoExample(id: "underline", title: "下划线", summary: "<u> 标签",
            html: "这是<u>下划线</u>文字示例，常用于<u>重要术语</u>标注。",
            family: .inlineText, tier: .basic),
        DemoExample(id: "strikethrough", title: "删除线", summary: "<s> / <del> / <strike>",
            html: "这是<s>删除线</s>文字，原价 <del>¥199</del> 现价 ¥99，旧版 <strike>已废弃</strike>。",
            family: .inlineText, tier: .basic),
        DemoExample(id: "sub-sup", title: "上标与下标", summary: "<sub> / <sup>",
            html: "化学公式 H<sub>2</sub>O、CO<sub>2</sub>，数学表达 x<sup>2</sup> + y<sup>3</sup> = z<sup>n</sup>，脚注<sup>[1]</sup>。",
            family: .inlineText, tier: .basic),
        DemoExample(id: "bold-italic", title: "粗体 + 斜体", summary: "嵌套样式合并",
            html: "这是<b><i>粗斜体</i></b>文字，展示<b>嵌套<i>组合</i></b>效果。再来一个<i><b>反向嵌套</b></i>。",
            family: .inlineText, tier: .nested),
        DemoExample(id: "nested-deep", title: "四层嵌套", summary: "<b><i><u><s> 四层组合",
            html: "普通文字 <b><i><u><s>四层嵌套加粗斜体下划线删除线</s></u></i></b> 恢复普通",
            family: .inlineText, tier: .nested, isRegression: true,
            note: "验证多层嵌套样式合并"),
        DemoExample(id: "code", title: "行内代码", summary: "<code> 标签",
            html: "使用 <code>let parser = try XMarkupParser()</code> 创建解析器，调用 <code>parser.parse(html)</code> 解析 HTML。",
            family: .inlineText, tier: .basic),
        DemoExample(id: "mark", title: "高亮标记", summary: "<mark> 标签",
            html: "请重点阅读<mark>这段高亮内容</mark>，它是<mark>核心知识点</mark>。普通文字作为对照。",
            family: .inlineText, tier: .basic),
    ]
}
