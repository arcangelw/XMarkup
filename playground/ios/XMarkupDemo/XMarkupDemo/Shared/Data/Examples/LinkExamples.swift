import Foundation

/// 链接族 — a
enum LinkExamples {
    static let all: [DemoExample] = [
        DemoExample(id: "link", title: "超链接", summary: "<a href=\"...\"> 标签",
            html: "访问 <a href=\"https://github.com\">GitHub</a>、<a href=\"https://swift.org\">Swift 官网</a>、<a href=\"https://developer.apple.com\">Apple Developer</a>。",
            family: .link, tier: .basic),
        DemoExample(id: "link-styled", title: "带样式的链接", summary: "链接 + 颜色 + 粗体组合",
            html: """
            点击 <a href="https://example.com"><span style="color:#FF6600"><b>橙色粗体链接</b></span></a>，\
            或者 <a href="https://example.com"><i>斜体链接</i></a>，\
            还有 <a href="https://example.com"><span style="color:#9900CC">紫色链接</span></a>。
            """,
            family: .link, tier: .nested),
    ]
}
