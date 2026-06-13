import SwiftUI
import WebKit

#if canImport(UIKit)

/// WKWebView 包装（iOS）— 加载 styledHTML（config.cssString 注入，与原生同源）
struct WebViewRepresentable: UIViewRepresentable {
    let html: String
    let config: DemoCanvasConfig

    func makeUIView(context: Context) -> WKWebView {
        let wv = WKWebView()
        wv.scrollView.bounces = false
        wv.loadHTMLString(WebViewRenderer.styledHTML(from: html, config: config), baseURL: nil)
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.loadHTMLString(WebViewRenderer.styledHTML(from: html, config: config), baseURL: nil)
    }
}
#elseif canImport(AppKit)

/// WKWebView 包装（macOS）
struct WebViewRepresentable: NSViewRepresentable {
    let html: String
    let config: DemoCanvasConfig

    func makeNSView(context: Context) -> WKWebView {
        let wv = WKWebView()
        wv.loadHTMLString(WebViewRenderer.styledHTML(from: html, config: config), baseURL: nil)
        return wv
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.loadHTMLString(WebViewRenderer.styledHTML(from: html, config: config), baseURL: nil)
    }
}
#endif
