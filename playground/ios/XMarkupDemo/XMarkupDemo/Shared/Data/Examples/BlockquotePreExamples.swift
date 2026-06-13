import Foundation

/// 引用与预格式族 — blockquote / pre
enum BlockquotePreExamples {
    static let all: [DemoExample] = [
        DemoExample(id: "blockquote", title: "引用块", summary: "<blockquote> 标签",
            html: """
            <p>有人说过：</p>
            <blockquote>任何足够先进的技术，都与魔法无异。—— Arthur C. Clarke</blockquote>
            <p>这句话在编程领域同样适用。</p>
            """,
            family: .blockquotePre, tier: .basic),
        DemoExample(id: "pre", title: "预格式化文本", summary: "<pre> 保留空白和换行",
            html: """
            <p>以下是代码块：</p>
            <pre>func greet(name: String) {
                print("Hello, \\(name)!")
            }

            greet(name: "XMarkup")</pre>
            <p>代码块结束。</p>
            """,
            family: .blockquotePre, tier: .basic),
    ]
}
