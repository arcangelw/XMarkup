import Foundation

/// 容错与边界族 — 跨族通用容错（集中放置，便于回归扫一遍）
enum RobustnessExamples {
    static let all: [DemoExample] = [
        DemoExample(id: "emoji-only", title: "纯 Emoji", summary: "仅包含 Emoji 字符",
            html: "🔄❤️🎉✨👀💬🔥💡🚀🌈🎭🦋",
            family: .robustness, tier: .boundary, isRegression: true,
            note: "验证纯 Emoji 字符串的字形与宽度"),
        DemoExample(id: "empty-doc", title: "空文档", summary: "空字符串输入",
            html: "",
            family: .robustness, tier: .boundary, isRegression: true,
            note: "验证空输入容错，不应崩溃"),
        DemoExample(id: "plain-text", title: "纯文本无标签", summary: "无任何 HTML 标签的纯文字",
            html: "这是一段没有任何 HTML 标签的纯文字，只有普通字符和标点符号。它应该被正确解析为一个段落。",
            family: .robustness, tier: .boundary, isRegression: true,
            note: "验证纯文本解析为单段落"),
        DemoExample(id: "unicode-mix", title: "Unicode 混合", summary: "多语言 + Emoji + 组合字符",
            html: "مرحبا 你好 こんにちは 안녕하세요 🌍 Héllo wörld 🇨🇳🇯🇵🇺🇸 👨‍👩‍👧‍👦",
            family: .robustness, tier: .boundary, isRegression: true,
            note: "验证多语言 + Emoji + 组合字符的 UTF-16 索引映射"),
        DemoExample(id: "html-entities", title: "HTML 实体转义", summary: "&amp; &lt; &gt; 等实体",
            html: "常用实体：&amp; &lt; &gt; &quot; &#x1F600; 还有一些特殊字符：© ® ™ — …",
            family: .robustness, tier: .boundary, isRegression: true,
            note: "验证 HTML 实体解码（含十六进制实体）"),
        DemoExample(id: "unclosed-tags", title: "未闭合标签", summary: "自动纠错容错能力",
            html: "<b>未闭合的粗体 <i>未闭合的斜体 <p>跨段落的标签</p> 后续文字",
            family: .robustness, tier: .boundary, isRegression: true,
            note: "验证未闭合标签的隐式关闭容错"),
    ]
}
