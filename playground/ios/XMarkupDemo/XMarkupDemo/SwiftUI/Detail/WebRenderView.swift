import SwiftUI

/// Web 渲染展示（WKWebView 加载 styledHTML，html + appendHTML 拼接）
struct WebRenderView: View {
    let example: DemoExample
    let config: DemoCanvasConfig

    var body: some View {
        WebViewRepresentable(
            html: example.html + (example.appendHTML ?? ""),
            config: config
        )
    }
}
