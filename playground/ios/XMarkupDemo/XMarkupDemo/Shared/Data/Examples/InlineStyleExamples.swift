import Foundation

/// 内联样式族 — span style（color / background / font-size）
enum InlineStyleExamples {
    static let all: [DemoExample] = [
        DemoExample(id: "text-color", title: "文字颜色", summary: "style=\"color:#RRGGBB\"",
            html: """
            <span style="color:#FF0000">红色</span>、<span style="color:#FF6600">橙色</span>、\
            <span style="color:#FFAA00">黄色</span>、<span style="color:#00AA00">绿色</span>、\
            <span style="color:#0066FF">蓝色</span>、<span style="color:#9900CC">紫色</span> 文字。
            """,
            family: .inlineStyle, tier: .basic),
        DemoExample(id: "bg-color", title: "背景颜色", summary: "style=\"background-color:#RRGGBB\"",
            html: """
            <span style="background-color:#FFFF00">黄色背景</span> / \
            <span style="background-color:#90EE90">绿色背景</span> / \
            <span style="background-color:#ADD8E6">蓝色背景</span> / \
            <span style="background-color:#FFB6C1">粉色背景</span> 的文字。
            """,
            family: .inlineStyle, tier: .basic),
        DemoExample(id: "color-named", title: "CSS 命名颜色", summary: "color:red / blue / green 等",
            html: """
            <span style="color:red">red</span>、<span style="color:blue">blue</span>、\
            <span style="color:green">green</span>、<span style="color:orange">orange</span>、\
            <span style="color:purple">purple</span>、<span style="color:teal">teal</span>。
            """,
            family: .inlineStyle, tier: .basic),
        DemoExample(id: "combined-color", title: "前景色 + 背景色", summary: "同时指定 color 和 background-color",
            html: """
            <span style="color:#FFFFFF;background-color:#333333"> 白字灰底 </span> \
            <span style="color:#000000;background-color:#FFD700"> 黑字金底 </span> \
            <span style="color:#FFFFFF;background-color:#FF4444"> 白字红底 </span> \
            <span style="color:#00FF00;background-color:#000000"> 绿字黑底 </span>
            """,
            family: .inlineStyle, tier: .nested),
        DemoExample(id: "color-rgb", title: "RGB 函数颜色", summary: "color:rgb(r,g,b) 格式",
            html: """
            <span style="color:rgb(255,0,0)">RGB 红色</span>、\
            <span style="color:rgb(0,128,255)">RGB 蓝色</span>、\
            <span style="color:rgb( 128 , 0 , 255 )">RGB 紫色（含空格）</span>。
            """,
            family: .inlineStyle, tier: .nested),
        DemoExample(id: "font-size", title: "自定义字号", summary: "px / em / % 单位",
            html: """
            默认字号 / <span style="font-size:24px">24px 大号</span> / <span style="font-size:10px">10px 小号</span> / \
            <span style="font-size:1.5em">1.5em 字号</span> / <span style="font-size:150%">150% 字号</span>。
            """,
            family: .inlineStyle, tier: .nested),
    ]
}
