import Foundation
import XMarkup

#if os(macOS)
import AppKit

/// XMarkup 标记文档的文本视图（macOS）
///
/// macOS 上 XMarkupTextView 是 NSTextView 的纯 UI 子类，
/// 主要用于 hr 自适应和 AsyncMediaLoader 集成。
/// blockquote 左侧竖线由 Core 层 NSTextBlock 处理。
open class XMarkupTextView: NSTextView {

    public var mediaLoader: AsyncMediaLoader?

    public func load(_ document: MarkupDocument, theme: MarkupTheme = .default) {
        let attr = document.render(theme: theme)
        let nsAttr = NSAttributedStringRenderer().render(attr)
        textStorage?.setAttributedString(nsAttr)
        loadMedia(nsAttr)
    }

    public func load(nsAttr: NSAttributedString) {
        textStorage?.setAttributedString(nsAttr)
    }

    private func loadMedia(_ nsAttr: NSAttributedString) {
        guard XMarkupUI.shared.config.enableMediaAutoLoad,
              let mutable = nsAttr.mutableCopy() as? NSMutableAttributedString
        else { return }
        let loader = mediaLoader ?? AsyncMediaLoader()
        loader.loadAttachments(
            in: mutable,
            layoutManager: layoutManager,
            hrMinWidth: XMarkupUI.shared.config.hrMinWidth
        )
    }
}

#endif
