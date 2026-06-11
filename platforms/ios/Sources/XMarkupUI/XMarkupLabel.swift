import Foundation
import XMarkup

#if canImport(UIKit) && !os(macOS)
import UIKit

/// XMarkup 标记文档的标签视图
///
/// 支持 hr 自适应宽度 + 异步媒体加载后刷新显示。
///
/// - Note: UILabel 不使用 NSLayoutManager，无法渲染 NSTextList 标记。
///         如需完整列表/交互支持，请使用 XMarkupTextView。
open class XMarkupLabel: UILabel {

    public var mediaLoader: AsyncMediaLoader?

    /// 渲染管线（可通过注入自定义管线替换默认行为）
    public var pipeline: RenderPipeline = .default

    /// 持有可变引用，hr 更新和媒体加载修改同一份数据
    private var currentMutableAttr: NSMutableAttributedString?

    public func load(_ document: MarkupDocument, theme: MarkupTheme = .default) {
        let nsAttr = pipeline.render(document, theme: theme)
        load(nsAttr: nsAttr)
    }

    public func load(nsAttr: NSAttributedString) {
        guard let mutable = nsAttr.mutableCopy() as? NSMutableAttributedString
        else { return }
        currentMutableAttr = mutable
        attributedText = mutable
        loadMedia(mutable)
    }

    override open func layoutSubviews() {
        super.layoutSubviews()
        // 更新 hr 宽度匹配当前 label 尺寸
        guard let storage = currentMutableAttr else { return }
        HorizontalRuleUpdater.update(
            in: storage,
            containerWidth: bounds.width,
            minWidth: XMarkupUI.shared.config.hrMinWidth
        )
        attributedText = storage  // 刷新显示
    }

    private func loadMedia(_ nsAttr: NSMutableAttributedString) {
        guard XMarkupUI.shared.config.enableMediaAutoLoad else { return }
        let loader = mediaLoader ?? AsyncMediaLoader()
        loader.loadAttachments(in: nsAttr,
            update: { [weak self] _ in
                DispatchQueue.main.async {
                    guard let self, let attr = self.currentMutableAttr else { return }
                    self.attributedText = attr
                }
            },
            completion: {}
        )
    }
}

#endif
