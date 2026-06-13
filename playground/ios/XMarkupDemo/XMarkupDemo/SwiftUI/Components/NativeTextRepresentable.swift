import SwiftUI

#if canImport(UIKit)
import UIKit

/// UITextView 包装 — `textContainerInset` 读 DemoCanvasConfig（与 Web padding 同源）
struct NativeTextRepresentable: UIViewRepresentable {
    let attributedString: NSAttributedString
    let config: DemoCanvasConfig

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.isScrollEnabled = true
        tv.alwaysBounceVertical = true
        tv.adjustsFontForContentSizeCategory = true
        tv.textContainer.lineFragmentPadding = 0
        tv.textContainerInset = config.uiTextContainerInset
        tv.backgroundColor = .clear
        tv.attributedText = attributedString
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.attributedText = attributedString
        uiView.textContainerInset = config.uiTextContainerInset
    }
}
#elseif canImport(AppKit)
import AppKit

/// NSTextView（嵌入 NSScrollView）包装 — `textContainerInset` 读 DemoCanvasConfig
struct NativeTextRepresentable: NSViewRepresentable {
    let attributedString: NSAttributedString
    let config: DemoCanvasConfig

    func makeNSView(context: Context) -> NSScrollView {
        let tv = NSTextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.isRichText = true
        tv.drawsBackground = false
        tv.textContainer?.lineFragmentPadding = 0
        tv.textContainerInset = config.nsTextContainerInset
        tv.textStorage?.setAttributedString(attributedString)
        tv.minSize = NSSize(width: 0, height: 0)
        tv.sizeToFit()

        let scroll = NSScrollView()
        scroll.documentView = tv
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let tv = nsView.documentView as? NSTextView else { return }
        tv.textContainerInset = config.nsTextContainerInset
        tv.textStorage?.setAttributedString(attributedString)
    }
}
#endif
