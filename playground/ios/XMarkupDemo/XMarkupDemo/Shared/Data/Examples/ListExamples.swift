import Foundation

/// 列表族 — ol / ul / li / dl
enum ListExamples {
    static let all: [DemoExample] = [
        DemoExample(id: "list-unordered", title: "无序列表", summary: "<ul><li> 标签",
            html: """
            <ul>
            <li>Swift 编程语言</li>
            <li>Objective-C 运行时</li>
            <li>C++ 核心引擎</li>
            </ul>
            """,
            family: .list, tier: .basic),
        DemoExample(id: "list-ordered", title: "有序列表", summary: "<ol><li> 标签",
            html: """
            <ol>
            <li>创建解析器实例</li>
            <li>调用 parse() 方法</li>
            <li>构建 MarkupDocument</li>
            <li>渲染为 AttributedString</li>
            </ol>
            """,
            family: .list, tier: .basic),
        DemoExample(id: "list-nested", title: "嵌套列表", summary: "ol 内嵌 ul，验证 isOrdered 判定",
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
            family: .list, tier: .nested, isRegression: true,
            note: "验证嵌套列表的 isOrdered 判定与连续编号"),
    ]
}
