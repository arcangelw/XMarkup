import Foundation
import XMarkup

#if os(macOS)
import AppKit

/// XMarkup 标记文档的文本视图（macOS）
///
/// macOS 上 XMarkupTextView 是 NSTextView 的子类，
/// 使用 XMarkupEnhancedRenderer 应用 NSTextBlock 视觉增强。
/// 主要用于 hr 自适应和 AsyncMediaLoader 集成。
open class XMarkupTextView: NSTextView {

    public var mediaLoader: AsyncMediaLoader?

    /// 渲染器（可通过注入自定义渲染器替换默认行为）
    public var renderer: any MarkupRenderer<NSAttributedString> = XMarkupEnhancedRenderer()

    public func load(_ document: MarkupDocument, theme: MarkupTheme = .default) {
        let attr = document.render(theme: theme)
        let nsAttr = renderer.render(attr)
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
