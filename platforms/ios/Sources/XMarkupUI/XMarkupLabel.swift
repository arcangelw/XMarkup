import Foundation
import XMarkup

#if canImport(UIKit) && !os(macOS)
import UIKit

/// XMarkup 标记文档的标签视图
///
/// 支持 hr 自适应宽度。
/// 媒体加载后通过 setNeedsDisplay 整体刷新。
open class XMarkupLabel: UILabel {

    public var mediaLoader: AsyncMediaLoader?

    public func load(_ document: MarkupDocument, theme: MarkupTheme = .default) {
        let attr = document.render(theme: theme)
        let nsAttr = NSAttributedStringRenderer().render(attr)
        load(nsAttr: nsAttr)
    }

    public func load(nsAttr: NSAttributedString) {
        guard let mutable = nsAttr.mutableCopy() as? NSMutableAttributedString
        else { return }
        attributedText = mutable
        loadMedia(mutable)
    }

    override open func layoutSubviews() {
        super.layoutSubviews()
        // 更新 hr 宽度匹配当前 label 尺寸
        guard let storage = attributedText.flatMap({ NSTextStorage(attributedString: $0) })
        else { return }
        HorizontalRuleUpdater.update(
            in: storage,
            containerWidth: bounds.width,
            minWidth: XMarkupUI.shared.config.hrMinWidth
        )
    }

    private func loadMedia(_ nsAttr: NSMutableAttributedString) {
        guard XMarkupUI.shared.config.enableMediaAutoLoad else { return }
        let loader = mediaLoader ?? AsyncMediaLoader()
        loader.loadAttachments(in: nsAttr,
            update: { [weak self] _ in
                DispatchQueue.main.async {
                    self?.setNeedsDisplay()
                }
            },
            completion: {}
        )
    }
}

#endif
